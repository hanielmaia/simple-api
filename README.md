<p align="center">
  <img src="https://media.licdn.com/dms/image/v2/D4D0BAQFqqkJoRRTbvg/company-logo_200_200/B4DZzUkmmOIwAI-/0/1773092891383/kxctecnologia_logo?e=2147483647&v=beta&t=ur-oxF2eamhQF4g4fDQjh6sy1lmH9W7pnOIrNAYOOzg" alt="KXC Tecnologia" width="120" />
</p>

# Simple-api — Desafio Técnico KXC

### API em produção: https://79sxb1oepb.execute-api.us-east-1.amazonaws.com/ — rotas `/` e `/connect`.

API Node.js + PostgreSQL provisionada na AWS 100% via Terraform, com CI/CD no GitHub Actions. A arquitetura foi desenhada em torno de três critérios: **organizada** (módulos reutilizáveis, um código para todos os ambientes), **segura** (rede privada, least privilege, sem chaves estáticas) e **resiliente** (Multi-AZ, rollback automático, autoscaling), sem abrir mão de **FinOps**.

```
simple-api/
├── application/       # API (Node.js + Express) + Dockerfile
├── infrastructure/    # Terraform: módulos, composição raiz e tfvars por ambiente
└── .github/workflows/ # CI/CD (deploy.yml) e validação de IaC (terraform.yml)
```

## Decisão central: um código, dois modos de exposição

O mesmo Terraform atende todos os ambientes; o que muda é a variável `expose_mode` e alguns parâmetros de custo/resiliência.

| | dev / hml | prod |
|---|---|---|
| Entrada | **API Gateway** (HTTP API) → VPC Link → Cloud Map | **ALB** público |
| Tasks | 1, **Fargate Spot** | 2 a 4 (autoscaling por CPU), on-demand, 2 AZs |
| Fora do horário | tasks zeradas (20h–8h e fins de semana) | sempre ligado |
| NAT Gateway | 1 (único) | 1 por AZ |
| RDS PostgreSQL | single-AZ | **Multi-AZ**, deletion protection |
| Foco | custo | resiliência |

**Por quê:** o ALB dá health check por target, connection draining e rolling deploy sem queda, que é o que prod precisa. O API Gateway elimina o custo fixo do ALB (diferencial FinOps do desafio) mas roteia por DNS (Cloud Map), sem draining nem health check no nível do balanceador, o que é aceitável fora de produção. A decisão é consciente e está no código (`expose_mode`), não em duas bases de código.

## 5.1 Arquitetura (diagrama e decisões)

Região `us-east-1`, 2 Zonas de Disponibilidade. CIDRs de exemplo do dev (`10.100.0.0/16`); hml usa `10.110.0.0/16` e prod `10.120.0.0/16`.

```
                                  INTERNET
                                      │
        ┌─────────────────────────────┴──────────────────────────────┐
        │ dev/hml: API Gateway (HTTP API, HTTPS)  ·  prod: ALB (:80)   │
        └─────────────────────────────┬──────────────────────────────┘
                                      │ dev/hml: VPC Link → Cloud Map  ·  prod: listener → target group
 ┌─ VPC 10.100.0.0/16 ────────────────┼─────────────────────────────────────────────┐
 │                                    │                                              │
 │  AZ us-east-1a                     │                      AZ us-east-1b           │
 │ ┌─ subnet PÚBLICA 10.100.1.0/24 ─┐ │ ┌─ subnet PÚBLICA 10.100.2.0/24 ─┐           │
 │ │  ALB (prod) · NAT Gateway      │ │ │  ALB (prod) · NAT (só em prod)  │  ← IGW   │
 │ │  [SG-ALB: entra 80/0.0.0.0/0]  │ │ │                                 │           │
 │ └────────────────────────────────┘ │ └─────────────────────────────────┘           │
 │ ┌─ subnet PRIVADA 10.100.11.0/24 ┐ │ ┌─ subnet PRIVADA 10.100.12.0/24 ┐           │
 │ │  ECS Fargate · task simple-api │◄┼►│  ECS Fargate · task simple-api  │           │
 │ │  [SG-ECS: entra 3000 só do     │ │ │  (prod: 2 a 4 tasks, uma por AZ)│           │
 │ │   SG-ALB / SG-VPCLink]         │ │ │                                 │           │
 │ └───────────────┬────────────────┘ │ └────────────────┬────────────────┘           │
 │                 │ 5432 (TLS)       │                  │                            │
 │ ┌───────────────▼──────────────────┴──────────────────▼───────────────┐            │
 │ │ RDS PostgreSQL (subnets privadas) · [SG-RDS: entra 5432 só do SG-ECS]│            │
 │ │ prod: Multi-AZ (primário em uma AZ, standby síncrono na outra)       │            │
 │ └──────────────────────────────────────────────────────────────────────┘            │
 └─────────────────────────────────────────────────────────────────────────────────────┘
   Saída das tasks (ECR, SSM, Logs) via NAT; pull de camadas do ECR via endpoint S3 gratuito.
```

**Caminho do tráfego (internet → banco):** cliente → (API Gateway + VPC Link, ou ALB) → **SG de entrada** → task ECS na porta 3000 → **SG-RDS** → PostgreSQL na 5432 com TLS. Cada salto só aceita o SG do salto anterior (nunca `0.0.0.0/0`), e o único recurso com entrada pública é a borda (API Gateway ou ALB).

**Security Groups:**

| SG | Entrada | Saída |
|---|---|---|
| ALB (prod) | 80 de `0.0.0.0/0` | 3000 para a VPC |
| VPC Link (dev/hml) | nenhuma | 3000 para a VPC |
| ECS | 3000 **somente** do SG de entrada (ALB ou VPC Link) | 443 (ECR/SSM/Logs via NAT), 5432 e DNS para a VPC |
| RDS | 5432 **somente** do SG do ECS | nenhuma |

**Trade-offs (custo × resiliência × complexidade):**

| Decisão | Ganho | Custo / risco |
|---|---|---|
| API Gateway + Cloud Map em dev/hml | Sem custo fixo de ALB (~US$ 16–22/mês), perto do Free Tier | Roteamento por DNS: sem draining nem health check no balanceador; configuração do VPC Link mais delicada |
| ALB em prod | Health check por target, draining, rolling deploy sem queda | Custo fixo mensal |
| NAT único fora de prod | ~US$ 33/mês economizados por NAT | Ponto único de falha de saída (aceitável em dev/hml) |
| NAT por AZ em prod | Saída sobrevive à queda de uma AZ | ~US$ 33/mês a mais por AZ |
| Fargate (sem EC2) | Sem servidores para patchear | Preço por vCPU maior que EC2 |
| Módulos Terraform pequenos | Reuso e leitura | Mais arquivos e indireção |

## 5.2 Plano de Autoscaling

Implementado no módulo `ecs` (`aws_appautoscaling_target` + `aws_appautoscaling_policy`) e ativado por ambiente em `environments/*.tfvars`.

| Parâmetro | Valor | Observação |
|---|---|---|
| Tipo | **Target Tracking** | A AWS cria e gerencia os alarmes |
| Métrica | `ECSServiceAverageCPUUtilization` | Aplicação leve e stateless: CPU é um bom sinal de carga |
| Alvo | **60% de CPU média** | Margem para absorver picos enquanto novas tasks sobem |
| Mínimo | **2 tasks** (prod) | Uma por AZ: sobrevive à queda de uma zona |
| Máximo | **4 tasks** (prod) | Teto de custo e proteção contra surtos |
| Scale-out | cooldown de **60 s** | Reage rápido; em geral dispara com CPU acima do alvo por ~3 min |
| Scale-in | cooldown de **120 s** | Mais conservador, para evitar oscilação; só reduz com CPU bem abaixo do alvo por ~15 min |
| dev / hml | **Sem autoscaling** (1 task fixa, Spot, desligada à noite) | Prioriza custo; não há carga real |

**Como o roteamento acompanha o scaling:**
- **prod (ALB):** o ECS Service está associado ao **target group** (`target_type = ip`). Cada task nova é **registrada sozinha** pelo ECS e só recebe tráfego depois de passar no health check (`GET /`, com *grace period* de 30 s). Ao reduzir, a task é removida do target group e o ALB faz *draining* de 30 s antes de encerrá-la.
- **dev/hml (API Gateway):** o ECS registra a task no **Cloud Map** (registro SRV, TTL de 10 s) e a remove quando o health check do container falha. O VPC Link consulta o Cloud Map, então novas tasks entram na rotação em segundos, sem configuração manual.
- O deploy usa 100% mínimo saudável / 200% máximo e **circuit breaker com rollback automático**.

## 5.3 Plano de Disaster Recovery (ideia básica)

**Objetivos (RPO = quanto dado se aceita perder; RTO = em quanto tempo o serviço volta):**

| Cenário | Estratégia | RPO | RTO |
|---|---|---|---|
| Falha de uma **task** | ECS recria sozinho; com 2 tasks, o ALB segue servindo | 0 | ~0 (prod) / 1–2 min (dev) |
| Falha de uma **AZ** | Tasks nas 2 AZs + **RDS Multi-AZ** (standby síncrono, failover automático) + NAT por AZ | ~0 | ~1–2 min |
| **Deploy ruim** | Circuit breaker faz rollback para a revisão anterior | 0 | minutos |
| Corrupção / exclusão de dados | **Restore do RDS por ponto no tempo** (backups automáticos) | até 5 min dentro da retenção | 30–60 min |
| Falha da **região** | **Backup & restore** em outra região | **≤ 24 h** (snapshot diário copiado) | **1–2 h** |

> Observação: a conta de teste (plano gratuito AWS) limita a retenção de backup a **1 dia**. Em conta paga, a retenção recomendada é de 7 a 35 dias (`db_backup_retention_days`). O Multi-AZ foi validado em prod (`MultiAZ=True`) e a queda de task foi testada (60/60 respostas 200).

**Como recuperar a aplicação e os dados:**
1. **Dados:** restaurar o RDS a partir do último snapshot (ou ponto no tempo) copiado para a região de recuperação.
2. **Aplicação:** a imagem fica no ECR com tag imutável (SHA do commit); copiá-la para o ECR da região de recuperação (ou habilitar *ECR cross-region replication*).
3. **Infraestrutura:** subir o **mesmo código Terraform** na região/conta de destino.
4. **Entrada:** apontar o DNS para o novo endpoint (no momento a API usa a URL padrão da AWS).

**Recriar em outra região ou conta com o mesmo Terraform** (idempotência e portabilidade):
- Nada é fixo no código: região, AZs, CIDRs, nomes e tamanhos vêm de `environments/<env>.tfvars`. Para outra região, troca-se `region`, `availability_zones_*` e rodam-se os mesmos comandos de "Como executar".
- Nomes são derivados de `projeto-ambiente`, e o state é isolado por workspace, então um novo ambiente não colide com o existente.
- O que muda ao migrar: o **bucket de state** é regional (rodar `bootstrap` na nova região/conta), o **ECR** é regional (publicar a imagem de novo), a **senha do banco** é gerada de novo (e o dado vem do snapshot) e o **OIDC provider** é um por conta (`create_github_oidc_provider`).
- Esse fluxo foi exercitado na prática: o **prod foi criado do zero, validado e destruído**, e dev e prod usam o mesmo código com tfvars diferentes.

**Pendências para um DR completo (próximos passos):**
- Variável `snapshot_identifier` no módulo `rds` para restaurar direto de um snapshot via Terraform (hoje o restore seria manual ou por ajuste do módulo).
- **Replicação automática de backups entre regiões** (`aws_db_instance_automated_backups_replication` ou AWS Backup), que levaria o RPO de regiões de 24 h para poucos minutos.
- **Teste periódico de restauração** (backup sem teste não é garantia) e um runbook com os passos acima.
- DNS (Route 53) com *failover* e ECR com replicação entre regiões.

## CI/CD

`deploy.yml` (push em `application/**`): OIDC → build → **scan Trivy (bloqueia CRITICAL/HIGH com correção)** → push no ECR (tag = SHA do commit, imutável) → render da task definition → deploy no ECS aguardando estabilidade. O ECS faz rollback automático (circuit breaker) se a nova versão não ficar saudável.
`terraform.yml`: `fmt`, `validate` e Checkov em PRs.

## Como executar

```bash
# 0) uma única vez: bucket S3 do state remoto (versionado, criptografado, sem acesso público)
cd infrastructure/bootstrap && terraform init && terraform apply && cd ..

terraform init
terraform workspace select -or-create dev          # um workspace por ambiente; state em S3
terraform apply -var-file=environments/dev.tfvars -target=module.ecr   # 1) cria o ECR
# 2) publicar a imagem inicial (linux/amd64) com a tag "bootstrap"
terraform apply -var-file=environments/dev.tfvars                      # 3) restante
```

Para ativar alarmes CloudWatch e o AWS Budget, crie `infrastructure/local.auto.tfvars` (ignorado pelo Git, para não publicar o e-mail) com `alert_email = "voce@exemplo.com"`. O SNS envia um e-mail de confirmação de assinatura que precisa ser aceito.

Depois configure a variável `AWS_ROLE_ARN` no GitHub com o output `github_deploy_role_arn`; a partir daí o deploy é pelo pipeline. Teste: `GET <api_url>/` e `GET <api_url>/connect`.

## Problemas encontrados e como foram resolvidos

**Armadilhas do repositório legado**

| # | Problema | Correção |
|---|---|---|
| 1 | Listener do ALB em **8080** | Passou para **80** |
| 2 | Ingress do ECS em **8084**, mas a app escuta na **3000** | Corrigido para 3000 |
| 3 | SG do ECS sem egress para o RDS (**5432**); `/connect` falharia | Regra adicionada, restrita à VPC |
| 4 | SG do ALB com egress `0.0.0.0/0` em todas as portas | Restrito à porta da app dentro da VPC |
| 5 | Placeholders `${ALB_SG_ID}`, `${NAT_GW_ID}`, `${IGW_ID}` sem resolução | Resolvidos na composição raiz |
| 6 | Módulo `route` quebrava: `for_each` com chaves só conhecidas no apply | Placeholders resolvidos por valor; chaves estáticas |
| 7 | Módulo `iam-role` aceitava uma única policy | Suporte a managed policies e policy opcional |
| 8 | `alb_controller_policy.json` é de **EKS**, não se aplica | Não utilizada (least privilege) |
| 9 | `.terraform.lock.hcl` ignorado pelo Git | Removido do `.gitignore` para versionar |
| 10 | Segredo em texto no módulo de Parameter Store | `value` marcado como `sensitive` e senha gerada, não digitada |

**Problemas surgidos na execução real**

| # | Problema | Correção |
|---|---|---|
| 11 | RDS PostgreSQL 16 exige **TLS**; a app conectava sem SSL | Suporte `DB_SSL` na app, validando o certificado com o bundle de CA da RDS embutido na imagem |
| 12 | Meu código novo no `index.js` virou chamada acidental (ASI, app sem `;`) e o container saía sem logar | `;` explícito; testado localmente antes do deploy |
| 13 | `db.t4g.micro` sem capacidade na região | `db.t3.micro` (também Free Tier); tipo de storage virou variável |
| 14 | Provider AWS: "inconsistent final plan" em SGs com regras dinâmicas (ocorreu em dev e em prod) | Reexecutar o apply converge; ideal futuro: `aws_vpc_security_group_*_rule` |
| 15 | Trust policy OIDC recusada: o repo usa **subject claims imutáveis** | A trust aceita os dois formatos, ainda restrita a repo e branch |
| 16 | Scan do Trivy bloqueou o deploy (OpenSSL e dependências) | `npm audit fix`, `apk upgrade` e npm removido da imagem final (0 CVEs HIGH) |
| 17 | Migrar um ambiente existente de ALB para API Gateway trava: o SG do ALB não é apagado enquanto o SG do ECS ainda o referencia | Atualizar antes a regra do SG do ECS e então rodar o apply. Não ocorre em ambientes novos |

## Validação em execução (prod)

Aplicado na conta de teste, validado e destruído em seguida:
- `GET /` e `GET /connect` pelo ALB, com PostgreSQL 16.13.
- 2 tasks saudáveis, uma em cada AZ (`us-east-1a` e `us-east-1b`); RDS Multi-AZ, criptografado e com deletion protection; autoscaling de 2 a 4 tasks.
- **Teste de queda**: uma task foi encerrada com requisições contínuas (60 s): **60 de 60 respostas 200**, e o serviço voltou sozinho para 2 tasks.

## FinOps

Estimativas mensais aproximadas (us-east-1, sem tráfego relevante). Valores de tabela pública, devem ser conferidos no AWS Pricing Calculator.

| Item | Custo fixo aproximado | Como foi tratado |
|---|---|---|
| NAT Gateway | ~US$ 33 por NAT | 1 único fora de prod; 1 por AZ só em prod (HA) |
| ALB | ~US$ 16–22 | Substituído por API Gateway em dev/hml |
| API Gateway HTTP API | ~US$ 1 por milhão de requisições (Free Tier no 1º ano) | Throttling configurado |
| Fargate 0,25 vCPU / 0,5 GB | ~US$ 9 on-demand | **Spot** (~70% menos) + desligamento fora do horário em dev/hml |
| RDS `db.t3.micro` | ~US$ 12 single-AZ (Free Tier elegível); ~2x em Multi-AZ | Multi-AZ só em prod |
| ECR / logs | centavos | Lifecycle (10 imagens) e retenção de logs de 14 dias |

Outras medidas: tags `Project/Environment/Owner/ManagedBy` em todos os recursos (via `default_tags`), endpoint S3 gratuito para o pull de imagens sem passar pelo NAT, AWS Budget (US$ 50/mês) e alarmes CloudWatch (CPU do ECS e do RDS, storage do RDS, 5xx do API Gateway/ALB) via SNS, ativos quando `alert_email` é informado.

Observação: interface endpoints (ECR, SSM, Logs) **não** foram usados porque, em baixo tráfego, custam mais que um único NAT.

## Limitações conhecidas e próximos passos

- **Checkov** roda em modo informativo (`soft_fail`). Achados aceitos conscientemente: ALB só HTTP (sem domínio), SSM com a chave KMS padrão da AWS em vez de CMK e policies de pipeline com `Resource: *` apenas nas ações que a API do ECS/ECR não permite restringir.

- **HTTPS no ALB**: sem domínio/certificado ACM, o ALB de prod serve só HTTP. O API Gateway já expõe HTTPS na URL padrão. Próximo passo: ACM + listener 443 com redirecionamento do 80.
- **State remoto** em S3 (versionado, criptografado, só TLS, lock nativo), um workspace por ambiente; o bucket é criado por `infrastructure/bootstrap`. A senha do banco fica no state, por isso o bucket é privado e o state nunca é versionado no Git. O bucket de state em si usa state local (limitação do bootstrap).
- **WAF** na frente do ALB/API Gateway não implementado.
- **Deploy do Terraform** é manual; a pipeline faz apenas `fmt`, `validate` e Checkov. Um job de `plan`/`apply` exigiria uma role separada de maior privilégio.
- **hml** está definido e validado só com `terraform plan`. **dev** e **prod** foram aplicados e testados em execução (prod foi destruído depois do teste para evitar custo).
- **Plano gratuito da AWS**: a conta de teste limita o backup do RDS a 1 dia (`db_backup_retention_days = 1` em `prod.tfvars`). Em conta paga, use 7 dias ou mais.
- O **rollback automático** (circuit breaker) está ativo, mas não foi exercitado com um deploy ruim de propósito.
- Rotação automática da senha do banco (Secrets Manager) como evolução.

<p align="center">
   Solução: Haniel Maia
</p>
