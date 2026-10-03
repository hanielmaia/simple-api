# Simple-api — Infraestrutura (Terraform)

> **Status:** a composição está completa e foi aplicada em dev e prod. Arquitetura, decisões, problemas encontrados e custos estão no [README da raiz](../README.md). O texto abaixo é o enunciado original do desafio, mantido como referência.

Infraestrutura como código (IaC) para provisionar e expor publicamente a **simple-api** (Node.js + PostgreSQL) na AWS, usando Amazon ECS (Fargate) atrás de um Application Load Balancer, dentro de uma VPC isolada criada por você.

Este repositório faz parte do **Desafio Técnico KXC**. O objetivo não é só "fazer rodar", mas avaliar como você estrutura ambientes em nuvem, automatiza entregas e organiza sua infraestrutura (organização, segurança e resiliência).

---

## ⚠️ Aviso importante — particularidades intencionais

> Como em qualquer projeto real, **este repositório contém erros e "pegadinhas" propositais**, colocados intencionalmente para avaliar sua análise crítica.
>
> Não assuma que tudo está correto. Antes de aplicar, **revise criticamente** se todas as informações, portas, regras de rede e variáveis estão coerentes com a aplicação — ou se algo precisa de ajuste.

Áreas que merecem atenção especial (sem dar a resposta pronta):

- **Portas**: confira em qual porta a aplicação realmente escuta (veja o `README.md` e o código em `application/`) e compare com o que está configurado na infraestrutura.
- **Security Groups**: revise as regras em `config/security_rules/`. Verifique se o fluxo *internet → ALB → ECS → aplicação* está realmente liberado ponta a ponta.
- **Encadeamento dos módulos**: o ALB, o Target Group e o Listener estão em módulos separados e precisam ser conectados corretamente entre si e ao serviço ECS.
- **Placeholders**: alguns arquivos de config usam marcadores como `${ALB_SG_ID}` e `${NAT_GW_ID}` que precisam ser resolvidos na composição raiz.
- **Arquivos de composição**: `main.tf` e `variables.tf` (raiz) estavam vazios e os `*.tfvars` incompletos. *(Resolvido: ver README da raiz.)*

Documente os problemas que encontrou e como os corrigiu. Isso faz parte da avaliação.

---

## Arquitetura alvo

```
                 Internet
                    │
                    ▼
          ┌───────────────────┐
          │  Application LB   │  (subnets públicas)
          │  Listener → TG    │
          └─────────┬─────────┘
                    │  (forward)
                    ▼
          ┌───────────────────┐
          │  ECS Service      │  (Fargate, subnets privadas)
          │  Task: simple-api │
          └─────────┬─────────┘
                    │
                    ▼
          ┌───────────────────┐
          │  PostgreSQL (RDS) │  (diferencial)
          └───────────────────┘
```

- **VPC isolada** com subnets públicas e privadas em 2 AZs.
- **Internet Gateway** para as subnets públicas e **NAT Gateway** para saída das subnets privadas.
- **ALB** público encaminhando para um **Target Group** (`target_type = ip`, Fargate) via **Listener**.
- **ECS Fargate** rodando o container da aplicação nas subnets privadas.
- **Security Groups** segregados para ALB e ECS.
- **IAM Roles** (execução da task e role da aplicação) seguindo *least privilege*.
- **Parameter Store** para variáveis/segredos da aplicação.

---

## Estrutura do repositório

```
infrastructure/
├── main.tf                 # composição raiz dos módulos
├── variables.tf            # variáveis raiz
├── environments/
│   ├── dev.tfvars          # um tfvars por ambiente (dev/hml/prod)
│   ├── hml.tfvars
│   └── prod.tfvars
├── config/
│   ├── policies/           
│   ├── routes/             
│   └── security_rules/     
└── modules/
    ├── network/
    │   ├── vpc/
    │   ├── subnet/
    │   ├── internet-gateway/
    │   ├── nat-gateway/
    │   ├── route/
    │   ├── route-table/
    │   ├── route-table-association/
    │   ├── alb/                     
    │   ├── target-group/            
    │   └── listener/                
    ├── security/
    │   ├── security-group/
    │   ├── iam-role/
    │   └── parameter-store/
    └── ecs/                         # cluster + task definition + service (Fargate)
```

Os recursos estão separados em módulos para você compor o encadeamento e expor seu raciocínio de organização.

---

## Fluxo esperado

1. **Fork** deste repositório.
2. **Containerização**: crie um `Dockerfile` otimizado para a aplicação em `application/`.
3. **Composição da IaC**: monte o `main.tf` (raiz) chamando os módulos na ordem correta de dependência:
   `vpc → subnets → igw/nat → route-tables/routes → security-groups → alb → target-group → listener → iam → ecs`.
4. **Variáveis**: declare-as em `variables.tf` e preencha os `environments/*.tfvars` (a seção de rede do `dev.tfvars` já está pronta como referência de padrão).
5. **Revisão crítica**: valide as particularidades sinalizadas acima (portas, SGs, placeholders) e ajuste o que estiver incorreto.
6. **Provisionamento**: aplique com Terraform (veja abaixo).
7. **CI/CD**: crie a pipeline (GitHub Actions, GitLab CI ou CodePipeline) que faça o build da imagem, push para o ECR e deploy no ECS.
8. **Validação**: confirme que a API responde publicamente pela URL do ALB (`GET /` e `GET /connect`).

---

## Como executar

Pré-requisitos: Terraform >= 1.5, credenciais AWS configuradas, aplicação já publicada no ECR.

```bash
cd infrastructure

# Inicializa providers e módulos
terraform init

# Revisa o plano para o ambiente desejado
terraform plan -var-file=environments/dev.tfvars

# Aplica
terraform apply -var-file=environments/dev.tfvars
```

Para validar os módulos isoladamente:

```bash
terraform fmt -recursive
terraform validate
```

---

## Requisitos e diferenciais do desafio

**Obrigatórios**
- Containerização com Dockerfile otimizado.
- Infraestrutura base 100% em Terraform (sem deploy manual pelo console).
- Pipeline de CI/CD com build + deploy automático.
- VPC nova e isolada.

**Diferenciais**
- Serviços gerenciados (ECS/EKS).
- PostgreSQL no Amazon RDS (em vez de container solto).
- Módulos Terraform bem estruturados (não tudo em um único `main.tf`).
- *Least privilege* nas roles da pipeline e da aplicação.
- **FinOps**: expor a API via **API Gateway** (HTTP API) integrado ao backend (VPC Link para o ECS ou serverless) para se manter no Free Tier, evitando o custo fixo do ALB.

---

## Entrega

Entregue mesmo que não conclua todos os passos. **Documente o que faltou, os problemas intencionais que identificou e como resolveria cada um.** O objetivo é entender seu momento técnico e seu raciocínio para resolver problemas.

---

<p align="center">
  desenvolvido e criado por<br>
  <strong>José Neto</strong><br>
  Cloud Architect | Squad Leader
</p>
