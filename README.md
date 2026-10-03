<p align="center">
  <img src="https://media.licdn.com/dms/image/v2/D4D0BAQFqqkJoRRTbvg/company-logo_200_200/B4DZzUkmmOIwAI-/0/1773092891383/kxctecnologia_logo?e=2147483647&v=beta&t=ur-oxF2eamhQF4g4fDQjh6sy1lmH9W7pnOIrNAYOOzg" alt="KXC Tecnologia" width="120" />
</p>

# Simple-api — Desafio Técnico KXC

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

## Arquitetura

```
                    Internet
                       │
        ┌──────────────┴───────────────┐
        │ prod: ALB (subnets públicas)  │   dev/hml: API Gateway HTTP API
        └──────────────┬───────────────┘            │ VPC Link
                       │                      Cloud Map (SRV)
                       ▼                            ▼
        ┌─────────────────────────────────────────────────┐
        │  ECS Fargate · subnets PRIVADAS (2 AZs)          │
        │  task: simple-api (usuário não-root)             │
        └───────────────┬───────────────┬─────────────────┘
                        │ 5432 (TLS)    │ 443 via NAT
                        ▼               ▼
              RDS PostgreSQL        ECR · SSM · CloudWatch Logs
              (subnets privadas)    (+ endpoint S3 gratuito)
```

- **VPC nova e isolada**, 2 AZs, subnets públicas (ALB/NAT) e privadas (ECS/RDS). Internet Gateway + NAT.
- **Security Groups encadeados**: entrada → ECS (3000) → RDS (5432). Nenhum recurso privado tem IP público.
- **Segredos**: senha do banco gerada pelo Terraform (`random_password`), guardada como `SecureString` no Parameter Store e injetada na task como `secret`. Nunca em tfvars ou imagem.
- **IAM least privilege**: execution role lê só os parâmetros desta app; task role sem permissões; role da pipeline limitada a ECR push do repo, update do service e `iam:PassRole` das duas roles.
- **CI/CD sem chaves estáticas**: GitHub Actions assume a role via OIDC, restrita ao repo e à branch `main`.

## CI/CD

`deploy.yml` (push em `application/**`): OIDC → build → **scan Trivy (bloqueia CRITICAL/HIGH com correção)** → push no ECR (tag = SHA do commit, imutável) → render da task definition → deploy no ECS aguardando estabilidade. O ECS faz rollback automático (circuit breaker) se a nova versão não ficar saudável.
`terraform.yml`: `fmt`, `validate` e Checkov em PRs.

## Como executar

```bash
cd infrastructure
terraform init
terraform workspace select -or-create dev          # um workspace por ambiente (state local)
terraform apply -var-file=environments/dev.tfvars -target=module.ecr   # 1) cria o ECR
# 2) publicar a imagem inicial (linux/amd64) com a tag "bootstrap"
terraform apply -var-file=environments/dev.tfvars                      # 3) restante
```

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

Outras medidas: tags `Project/Environment/Owner/ManagedBy` em todos os recursos (via `default_tags`), endpoint S3 gratuito para o pull de imagens sem passar pelo NAT, AWS Budget e alarmes opcionais (`alert_email`).

Observação: interface endpoints (ECR, SSM, Logs) **não** foram usados porque, em baixo tráfego, custam mais que um único NAT.

## Limitações conhecidas e próximos passos

- **HTTPS no ALB**: sem domínio/certificado ACM, o ALB de prod serve só HTTP. O API Gateway já expõe HTTPS na URL padrão. Próximo passo: ACM + listener 443 com redirecionamento do 80.
- **State local** (um workspace por ambiente). Em produção: backend S3 com lock e criptografia (bloco já preparado em `versions.tf`). A senha do banco fica no state, por isso ele não é versionado.
- **WAF** na frente do ALB/API Gateway não implementado.
- **Deploy do Terraform** é manual; a pipeline faz apenas `fmt`, `validate` e Checkov. Um job de `plan`/`apply` exigiria uma role separada de maior privilégio.
- **hml** está definido e validado só com `terraform plan`. **dev** e **prod** foram aplicados e testados em execução (prod foi destruído depois do teste para evitar custo).
- **Plano gratuito da AWS**: a conta de teste limita o backup do RDS a 1 dia (`db_backup_retention_days = 1` em `prod.tfvars`). Em conta paga, use 7 dias ou mais.
- O **rollback automático** (circuit breaker) está ativo, mas não foi exercitado com um deploy ruim de propósito.
- Rotação automática da senha do banco (Secrets Manager) como evolução.

<p align="center">
  Solução: Haniel Maia
</p>
