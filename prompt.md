# Prompt: Implementar Melhorias de Segurança, DRY e Operacionais

## Seu Papel

Você é um **Senior DevOps/Cloud Engineer** especialista em AWS, Terraform, GitHub Actions e segurança cloud-native. Você vai implementar uma série de melhorias neste repositório.

---

## Contexto do Projeto

Este repositório é um **mono-repo template** para um domínio dentro de uma arquitetura **AWS Data Mesh**. Cada domínio é autônomo — possui seus próprios data contracts, infraestrutura (IaC) e pipeline de deployment.

### Stack Tecnológico

| Tecnologia        | Versão / Detalhes                                    |
| ----------------- | ---------------------------------------------------- |
| Python            | 3.11                                                 |
| Apache Spark      | 3.5.6 (via AWS Glue 5.1)                            |
| Terraform         | >= 1.14                                              |
| AWS Provider      | ~> 5.0                                               |
| CI/CD             | GitHub Actions                                       |
| Auth (CI/CD)      | GitHub OIDC → IAM Roles (sem credentials estáticas)  |
| Data Format       | Apache Iceberg (refined/curated), Hive/Parquet (raw) |
| Orquestração      | AWS Step Functions                                   |
| Container (local) | Docker (Python 3.11-slim + Spark 3.5)                |

### Arquitetura de Dados (3 camadas S3)

```
raw      → Landing zone, dados como recebidos da fonte (Hive/Parquet)
refined  → Limpos, conformados, joinable (Iceberg)
curated  → Prontos para consumo, agregados (Iceberg)
```

### Organização do Repositório

```
.
├── setup/
│   ├── domain.json              # Single source of truth (nome do domínio, abbr, região)
│   ├── bootstrap.sh             # Setup local idempotente
│   └── init-terraform.sh        # Gera backend.conf para cada ambiente
├── src/
│   ├── core/                    # Biblioteca Python compartilhada (.whl), usada por todos os jobs
│   └── jobs/<project>/          # Scripts PySpark standalone (NÃO packaged no wheel)
├── tests/                       # Unit tests (pytest)
├── infrastructure/
│   ├── modules/                 # Módulos Terraform reutilizáveis
│   │   ├── glue_job/            # Provisiona um Glue job
│   │   ├── glue_iceberg_table/  # Tabela Iceberg + 3 optimizers automáticos
│   │   ├── glue_catalog_table/  # Tabela Hive/Parquet standard
│   │   ├── glue_catalog_database/
│   │   ├── glue_table_optimizer/  # ⚠ Módulo standalone de optimizer (NÃO USADO)
│   │   ├── iam_glue_job/        # IAM role para Glue jobs (per-project)
│   │   ├── iam_table_optimizer/ # IAM role para Table Optimizer (per-project)
│   │   ├── iam_role/            # IAM role genérico (usado só por SFN)
│   │   ├── s3_bucket/           # Bucket S3 com encryption, versioning, lifecycle
│   │   └── stepfunction_pipeline/  # Step Functions state machine + log group
│   ├── foundation/              # Infra compartilhada: buckets S3, databases Glue, VPC, IAM SFN
│   ├── projects/                # Stacks per-project (tables, jobs, optimizers, pipelines)
│   │   ├── _template/           # Template para novos projetos (cp e edite project.json)
│   │   ├── project01/
│   │   └── test02/
│   └── environments/
│       ├── dev/main.tf + outputs.tf   # Root module: wires foundation, re-exports outputs
│       ├── int/main.tf + outputs.tf
│       └── prod/main.tf + outputs.tf
├── .github/workflows/
│   ├── ci.yml                   # Lint, test, terraform validate, build wheel
│   ├── deploy-dev.yml           # Deploy para Dev (push em `dev`)
│   ├── deploy-int.yml           # Deploy para Int (push em `int`)
│   ├── deploy-prod.yml          # Deploy para Prod (push em `main`)
│   └── terraform-plan-pr.yml   # Terraform plan em PRs com comentário no PR
├── Dockerfile
├── Makefile
└── pyproject.toml
```

### Como os Projetos Funcionam

Cada projeto é um **Terraform root module independente** com seu próprio remote state. Os projetos leem os outputs da foundation via `data.terraform_remote_state`:

```
environments/<env>/main.tf
  → module "foundation" { source = "../../foundation" }
  → outputs.tf re-exporta todos os outputs do module.foundation

projects/<name>/data.tf
  → data.terraform_remote_state.foundation (lê o state do environment)

projects/<name>/locals.tf
  → local.foundation = data.terraform_remote_state.foundation.outputs
  → local.config     = jsondecode(file("project.json"))
  → local.domain     = jsondecode(file("../../../setup/domain.json"))
```

### CI/CD Flow

```
feature/* ──PR──▶ dev ──PR──▶ int ──PR──▶ main (prod)

Deploy order (por ambiente):
  1. Foundation (Terraform Apply em environments/<env>/)
  2. Artifacts  (Upload wheel + job scripts para S3)
  3. Projects   (Terraform Apply em cada projects/<name>/, em paralelo via matrix)
```

Projetos são auto-discovered via `find infrastructure/projects -name 'project.json'`. A detecção de mudanças usa `dorny/paths-filter` para decidir se roda foundation, artifacts, e/ou projetos.

### domain.json Atual

```json
{
  "domain_name": "finance01",
  "domain_abbr": "f01",
  "aws_region": "eu-west-1"
}
```

---

## Diretrizes de Implementação

- **Plug-and-play**: Novos projetos devem funcionar copiando `_template/` e editando apenas `project.json`, `tables.tf`, `jobs.tf`, `pipelines.tf`.
- **DRY (Don't Repeat Yourself)**: Código/configuração não deve ser duplicado entre ambientes ou projetos.
- **Segurança**: Seguir AWS Well-Architected Framework, CIS AWS Benchmark, e SLSA para supply chain.
- **Consistência**: Todos os resources usam as mesmas convenções de naming: `{domain_abbr}-{purpose}-{account_id}-{env}`.

---

## Melhorias a Implementar

As melhorias estão organizadas por prioridade. Implemente cada uma mantendo a compatibilidade com a arquitetura existente.

> **NOTA**: Os itens marcados com `[NÃO IMPLEMENTAR]` são apenas para referência. Serão tratados em um momento futuro.

---

### P0-01 — S3: Bucket Policy para forçar HTTPS (deny http)

**Gravidade:** CRÍTICA
**Arquivo alvo:** `infrastructure/modules/s3_bucket/main.tf`

**Problema:** Nenhum dos 4 buckets (raw, refined, curated, artifacts) possui uma bucket policy que negue requests sem TLS. Dados podem ser transmitidos via HTTP plano.

**Requisito:** Adicionar um `aws_s3_bucket_policy` ao módulo S3 que implemente a condição `aws:SecureTransport = false → Deny`. Isso deve ser aplicado automaticamente a todo bucket criado pelo módulo.

**Referência:**
```terraform
resource "aws_s3_bucket_policy" "deny_insecure" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.deny_insecure.json
}

data "aws_iam_policy_document" "deny_insecure" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
```

**Critério de aceite:** Todo bucket criado pelo módulo rejeita requests HTTP automaticamente. Nenhum bucket existente precisa de alteração manual.

---

### P0-02 — GitHub Actions: Pinning por SHA

**Gravidade:** CRÍTICA
**Arquivos alvo:** Todos os `.github/workflows/*.yml`

**Problema:** Todas as GitHub Actions estão referenciadas por tag mutável (`@v4`, `@v3`, etc.). Um mantenedor comprometido pode alterar o código da action sem que se perceba (supply-chain attack).

**Requisito:** Substituir todas as referências de tag por SHA imutável. A tag deve ser mantida como comentário inline para legibilidade.

**Actions usadas atualmente:**
```
actions/checkout@v4
actions/github-script@v7
actions/setup-python@v5
actions/upload-artifact@v4
aws-actions/configure-aws-credentials@v4
dorny/paths-filter@v3
dorny/test-reporter@v1
hashicorp/setup-terraform@v3
```

**Formato esperado:**
```yaml
- uses: actions/checkout@<full-sha>  # v4
```

**Como obter os SHAs:** Para cada action, resolver o SHA do commit que a tag aponta:
```bash
git ls-remote --tags https://github.com/actions/checkout.git | grep 'refs/tags/v4$'
```
Ou acesse https://github.com/{owner}/{repo}/tags e copie o full commit SHA da tag.

**Critério de aceite:** Todas as referências `uses:` em todos os 5 workflows usam SHA completo (40 caracteres hex) com a tag como comentário.

---

### P0-03 — IAM: Wildcard Resources em EC2 e CloudWatch Logs `[NÃO IMPLEMENTAR]`

**Gravidade:** CRÍTICA
**Arquivos alvo:** `infrastructure/modules/iam_glue_job/main.tf`, `infrastructure/foundation/iam_orchestration.tf`

**Problema 1:** O statement `EC2NetworkAccess` no módulo `iam_glue_job` usa `resources = ["*"]` para ações como `CreateNetworkInterface`, `DeleteNetworkInterface`. Deveria ser limitado aos subnet ARNs da VPC.

**Problema 2:** O statement `CloudWatchLogs` da role SFN (`iam_orchestration.tf`) dá 8 ações de logs em `resources = ["*"]`, incluindo `PutResourcePolicy` e `DeleteLogDelivery`.

> Estes itens serão ajustados futuramente. Não implementar agora.

---

### P1-01 — VPC Flow Logs

**Gravidade:** ALTA
**Arquivo alvo:** `infrastructure/foundation/vpc.tf`

**Problema:** A VPC não tem Flow Logs habilitados. Sem eles, é impossível investigar tráfego anômalo ou diagnosticar falhas de conectividade nos Glue jobs.

**Requisito:** Adicionar VPC Flow Logs para a VPC do domínio, direcionando para um CloudWatch Log Group com retenção configurável.

**Referência de implementação:**
```terraform
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.domain_abbr}-vpc-${var.env}/flow-logs"
  retention_in_days = 90
  tags              = local.common_tags
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "${var.domain_abbr}-vpc-flow-logs-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "vpc_flow_logs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.domain_abbr}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_permissions.json
}

data "aws_iam_policy_document" "vpc_flow_logs_permissions" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-flow-log-${var.env}"
  })
}
```

**Critério de aceite:** VPC Flow Logs criados automaticamente em cada ambiente. Log group com retenção de 90 dias. Visible no CloudWatch console.

---

### P1-02 — S3 Access Logging

**Gravidade:** ALTA
**Arquivo alvo:** `infrastructure/modules/s3_bucket/main.tf`, `infrastructure/foundation/s3.tf`

**Problema:** Nenhum bucket tem Server Access Logging habilitado. Sem access logs, é impossível auditar quem leu/gravou dados nos data lakes.

**Requisito:** Criar um bucket de logs dedicado no foundation e configurar o módulo S3 para aceitar um parâmetro opcional `logging_bucket_id`. Quando fornecido, habilitar Server Access Logging.

**Alterações necessárias:**

1. **No módulo `s3_bucket/main.tf`** — Adicionar variável e resource opcionais:
```terraform
variable "logging_bucket_id" {
  description = "S3 bucket ID for server access logging. Leave empty to disable."
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "Prefix for access log objects within the logging bucket."
  type        = string
  default     = ""
}

resource "aws_s3_bucket_logging" "this" {
  count         = var.logging_bucket_id != "" ? 1 : 0
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_bucket_id
  target_prefix = var.logging_prefix != "" ? var.logging_prefix : "${aws_s3_bucket.this.id}/"
}
```

2. **No foundation `s3.tf`** — Criar o bucket de logs e passar para os demais:
```terraform
module "s3_logs" {
  source            = "../modules/s3_bucket"
  bucket_name       = "${var.domain_abbr}-logs-${data.aws_caller_identity.current.account_id}-${var.env}"
  enable_versioning = false
  tags              = local.common_tags
}

# Nos módulos existentes, adicionar:
#   logging_bucket_id = module.s3_logs.bucket_id
#   logging_prefix    = "raw/"  (ou "refined/", "curated/", "artifacts/")
```

3. **No foundation `outputs.tf`** — Adicionar output:
```terraform
output "s3_logs_bucket_id" {
  value = module.s3_logs.bucket_id
}
```

4. **No `environments/*/outputs.tf`** — Re-exportar:
```terraform
output "s3_logs_bucket_id" {
  value = module.foundation.s3_logs_bucket_id
}
```

**Notas importantes:**
- O bucket de logs NÃO deve ter logging habilitado nele mesmo (loop infinito).
- O bucket de logs deve ter `prevent_destroy = true` (dados de auditoria).
- O ACL do bucket de logs precisa permitir o serviço S3 escrever nele (`aws_s3_bucket_acl` com `log-delivery-write` ou usar bucket policy com `logging.s3.amazonaws.com` como principal).

**Critério de aceite:** Os 4 buckets de dados (raw, refined, curated, artifacts) enviam access logs para o bucket de logs. O bucket de logs é criado automaticamente na foundation.

---

### P1-03 — S3 Encryption com Customer-Managed Key (CMK)

**Gravidade:** ALTA
**Arquivo alvo:** `infrastructure/modules/s3_bucket/main.tf`, `infrastructure/foundation/s3.tf`

**Problema:** O módulo S3 usa `sse_algorithm = "aws:kms"` sem especificar `kms_master_key_id`. Isso usa a chave gerenciada pela AWS (`aws/s3`), que não permite rotation policy customizada, key policies granulares, ou cross-account access control.

**Requisito:** Criar uma KMS key dedicada ao domínio no foundation e configurar o módulo S3 para aceitar um `kms_key_arn` opcional.

**Alterações necessárias:**

1. **Criar `infrastructure/foundation/kms.tf`**:
```terraform
resource "aws_kms_key" "data_lake" {
  description             = "KMS key for ${var.domain_abbr} data lake encryption - ${var.env}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "data_lake" {
  name          = "alias/${var.domain_abbr}-data-lake-${var.env}"
  target_key_id = aws_kms_key.data_lake.id
}
```

2. **No módulo `s3_bucket/main.tf`** — Adicionar variável opcional:
```terraform
variable "kms_key_arn" {
  description = "ARN of a KMS CMK for S3 encryption. If empty, uses AWS-managed key."
  type        = string
  default     = ""
}
```
E atualizar o resource de encryption:
```terraform
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = true
  }
}
```

3. **Outputs e re-exports**: Adicionar `kms_key_arn` e `kms_key_id` aos outputs do foundation, dos environments, e usar nas chamadas dos módulos S3.

4. **IAM**: Garantir que as roles Glue e Table Optimizer tenham permissão `kms:Decrypt`, `kms:Encrypt`, `kms:GenerateDataKey` na key do data lake. Adicionar o statement nas policies dos módulos `iam_glue_job` e `iam_table_optimizer`.

**Critério de aceite:** Uma KMS CMK é criada por ambiente. Todos os buckets S3 do domínio usam essa CMK. IAM roles têm permissão para usar a chave. A chave tem rotation automático habilitado.

---

### P1-04 — Remover Internet Gateway não utilizado

**Gravidade:** ALTA
**Arquivo alvo:** `infrastructure/foundation/vpc.tf`

**Problema:** Um Internet Gateway é criado e attached à VPC, mas **nenhuma route table o referencia**. As subnets são privadas e não há rota `0.0.0.0/0 → igw`. O recurso é inútil e expande a superfície de ataque.

**Requisito:** Remover por completo o resource `aws_internet_gateway.main` do arquivo `vpc.tf`.

**Código a remover:**
```terraform
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-igw-${var.env}"
  })
}
```

**Verificação antes de remover:** Confirme com `grep -rn 'aws_internet_gateway\|igw' infrastructure/` que nenhum outro resource referencia o IGW. Se houver, remova a referência também.

**Critério de aceite:** O Internet Gateway não está mais presente no código Terraform. Nenhum resource órfão referencia o ID dele.

---

### P1-05 — Security Groups: Restringir Egress

**Gravidade:** ALTA
**Arquivo alvo:** `infrastructure/foundation/subnets.tf`

**Problema:** Ambos os security groups (`glue_endpoint` e `glue_job`) permitem egress para `0.0.0.0/0`. Como há VPC endpoints para S3 e Glue, o egress irrestrito é desnecessário e facilita exfiltração em caso de comprometimento.

**Requisito:** Substituir o egress `0.0.0.0/0` por regras específicas:

Para o SG **`glue_endpoint`**: o egress deve permitir apenas tráfego dentro da VPC CIDR (já que é um endpoint interface).

Para o SG **`glue_job`**:
- Self-reference (shuffle traffic entre workers) — já existe como ingress, adicionar como egress TCP.
- HTTPS (443) para VPC CIDR (acesso ao Glue endpoint e S3 via VPC endpoints).

**Referência para `glue_job`:**
```terraform
egress {
  description = "Glue worker shuffle traffic (self)"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  self        = true
}

egress {
  description = "HTTPS to VPC endpoints (S3, Glue)"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = [var.vpc_cidr]
}
```

**Critério de aceite:** Nenhum security group permite egress `0.0.0.0/0`. Glue jobs continuam funcionando (shuffle + acesso a S3/Glue via VPC endpoints).

---

### P2-01 — CI/CD: Refatorar Workflows de Deploy em Reusable Workflow

**Gravidade:** MÉDIA
**Arquivos alvo:** `.github/workflows/deploy-dev.yml`, `deploy-int.yml`, `deploy-prod.yml`

**Problema:** Os 3 workflows são ~99% idênticos (~258 linhas cada). Diferem apenas em: branch trigger, secret name (`AWS_ROLE_ARN_DEV/INT/PROD`), e variável `ENV`. Total: ~774 linhas com duplicação massiva. Qualquer fix/melhoria precisa ser aplicado 3 vezes.

**Requisito:** Criar um **reusable workflow** (`workflow_call`) e 3 wrappers mínimos que o invocam.

**Estrutura desejada:**
```
.github/workflows/
  _deploy.yml          # Reusable workflow (toda a lógica)
  deploy-dev.yml       # ~15 linhas: trigger on dev, chama _deploy com env=dev
  deploy-int.yml       # ~15 linhas: trigger on int, chama _deploy com env=int
  deploy-prod.yml      # ~15 linhas: trigger on main, chama _deploy com env=prod
```

**Exemplo do reusable workflow (`_deploy.yml`):**
```yaml
name: _deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
        description: "Target environment (dev, int, prod)"
    secrets:
      AWS_ROLE_ARN:
        required: true

permissions:
  contents: read
  id-token: write

env:
  PYTHON_VERSION: "3.11"
  TERRAFORM_VERSION: "1.14.5"
  ENV: ${{ inputs.environment }}

jobs:
  # ... toda a lógica atual (changes, discover, foundation, artifacts, deploy-projects)
  # Substituir qualquer referência a secrets.AWS_ROLE_ARN_DEV por secrets.AWS_ROLE_ARN
```

**Exemplo de wrapper (`deploy-dev.yml`):**
```yaml
name: Deploy - Dev

on:
  push:
    branches: [dev]
    paths-ignore:
      - "**.md"
      - "LICENSE"
      - "docs/**"

concurrency:
  group: deploy-dev
  cancel-in-progress: false

jobs:
  deploy:
    uses: ./.github/workflows/_deploy.yml
    with:
      environment: dev
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN_DEV }}
```

**Critério de aceite:** Lógica de deploy existe em um único lugar (`_deploy.yml`). Os 3 wrappers têm no máximo ~20 linhas cada. Comportamento idêntico ao atual.

---

### P2-02 — Corrigir Comentários Errados nos Workflows Int/Prod

**Gravidade:** MÉDIA
**Arquivos alvo:** `.github/workflows/deploy-int.yml`, `.github/workflows/deploy-prod.yml`

**Problema:** Ambos os arquivos têm o comentário de cabeçalho:
```yaml
# Triggered on push to the `dev` branch.
```
Isso é incorreto — `deploy-int.yml` dispara em `int` e `deploy-prod.yml` em `main`.

**Requisito:** Se o P2-01 (reusable workflow) for implementado, estes arquivos serão substituídos e este item é resolvido automaticamente. Caso contrário, corrigir os comentários:

- `deploy-int.yml`: `# Triggered on push to the \`int\` branch.`
- `deploy-prod.yml`: `# Triggered on push to the \`main\` branch.`

**Critério de aceite:** Comentários refletem o trigger real de cada workflow.

---

### P2-03 — CI: Terraform Validate para Project Stacks

**Gravidade:** MÉDIA
**Arquivo alvo:** `.github/workflows/ci.yml`

**Problema:** O job `terraform-validate` do CI só valida os root modules em `infrastructure/environments/{dev,int,prod}`. Os project stacks em `infrastructure/projects/*/` NÃO são validados. Um erro de sintaxe em `tables.tf` de um projeto só é detectado no deploy (durante `terraform apply`).

**Requisito:** Adicionar um job (ou estender o existente) que descubra dinamicamente todos os diretórios de projetos (excluindo `_template`) e rode `terraform init -backend=false && terraform validate` em cada um.

**Referência de implementação:**
```yaml
  terraform-validate-projects:
    name: Terraform Validate Projects
    needs: changes
    if: needs.changes.outputs.infra == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>  # v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@<sha>  # v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Validate all project stacks
        run: |
          PROJECTS=$(find infrastructure/projects -maxdepth 2 -name 'project.json' \
            ! -path '*/_template/*' | xargs -I{} dirname {})
          FAILED=0
          for DIR in $PROJECTS; do
            echo "──── Validating $(basename $DIR) ────"
            terraform -chdir="$DIR" init -backend=false -input=false > /dev/null 2>&1
            if ! terraform -chdir="$DIR" validate; then
              FAILED=1
            fi
          done
          exit $FAILED
```

**Critério de aceite:** PRs que alterem `infrastructure/projects/**` executam `terraform validate` em todos os projetos. Erros de sintaxe bloqueiam o merge.

---

### P2-04 — Remover Módulo Terraform Não Utilizado: `glue_table_optimizer`

**Gravidade:** MÉDIA
**Diretório alvo:** `infrastructure/modules/glue_table_optimizer/`

**Problema:** O módulo `glue_table_optimizer` (123 linhas) é um módulo standalone para criar optimizers de tabelas Iceberg. Porém, o módulo `glue_iceberg_table` já cria os 3 optimizers inline (compaction, retention, orphan_file_deletion). Nenhum projeto ou arquivo referencia `glue_table_optimizer`.

**Verificação:**
```bash
grep -rn 'glue_table_optimizer' infrastructure/ --include='*.tf'
# Deve retornar zero resultados fora do próprio módulo
```

**Requisito:** Remover o diretório `infrastructure/modules/glue_table_optimizer/` por completo.

**Critério de aceite:** O diretório não existe mais. Nenhuma referência ao módulo em nenhum arquivo `.tf`.

---

### P2-05 — Remover Placeholders Vazios do Foundation

**Gravidade:** MÉDIA
**Arquivos alvo:** `infrastructure/foundation/iam_glue_job.tf`, `infrastructure/foundation/iam_table_optimizer.tf`

**Problema:** Ambos contêm apenas um comentário dizendo "intencionalmente vazio, mantido como placeholder". Não adicionam valor e criam ruído.

**Requisito:** Remover ambos os arquivos.

**Critério de aceite:** Os arquivos não existem mais. Nenhuma referência a eles em outros arquivos.

---

### P2-06 — Wheel Versionada com Semver Automático

**Gravidade:** MÉDIA
**Arquivos alvo:** `pyproject.toml`, `.github/workflows/_deploy.yml` (ou `deploy-dev/int/prod.yml`), `Makefile`

**Problema:** A wheel é sempre salva como `core-latest-py3-none-any.whl`, sobrescrevendo a versão anterior. Não há:
1. Versionamento semântico do artefato.
2. Possibilidade de rollback para uma versão anterior.
3. Rastreabilidade de qual versão está deployed em qual ambiente.

**Requisito:** Implementar versionamento baseado no short SHA do commit + manter um link simbólico (ou cópia) `core-latest-*` para compatibilidade.

**Alterações necessárias:**

1. **No `pyproject.toml`** — Usar `setuptools-scm` ou gerar versão no build:
```toml
[project]
dynamic = ["version"]

[tool.setuptools.dynamic]
version = {attr = "core.__version__"}
```
Ou injetar no workflow via `--build-number`.

2. **No workflow de artifacts** — Upload com versão + latest:
```yaml
- name: Build and upload wheel
  run: |
    SHORT_SHA="${GITHUB_SHA::8}"
    VERSION="1.0.0+${SHORT_SHA}"
    # ... build with version ...
    WHEEL=$(ls dist/*.whl | head -1)
    aws s3 cp "$WHEEL" "s3://${BUCKET}/wheels/${WHEEL##*/}"
    aws s3 cp "$WHEEL" "s3://${BUCKET}/wheels/core-latest-py3-none-any.whl"
```

3. **Nos Glue jobs** — Manter referência a `core-latest-*` (sem mudança). O versionamento serve para auditoria e rollback manual.

**Critério de aceite:** Cada build gera uma wheel com identificação única. `core-latest-*` continua existindo para backward compatibility. Versões anteriores permanecem no bucket para rollback.

---

### P3-01 — `.terraform.lock.hcl` Consistente

**Gravidade:** BAIXA
**Arquivos alvo:** Todos os projetos em `infrastructure/projects/*/`

**Problema:** Lock files existem em `_template/` e `project01/`, mas não em `test02/`. Inconsistência pode causar provider version drift entre projetos.

**Requisito:** Garantir que `.terraform.lock.hcl` esteja commitado em TODOS os projetos, ou adicionar ao `.gitignore` e não commitar em nenhum. A melhor prática do Terraform recomenda **commitar** o lock file.

**Ação:** Rodar `terraform init` no `test02/` para gerar o lock file e commitá-lo. Ou, se optar por não commitar, adicionar `**/.terraform.lock.hcl` ao `.gitignore` e remover os existentes.

**Critério de aceite:** Política consistente: todos têm ou nenhum tem o lock file.

---

### P3-02 — Docker `docker-run`: Não expor credentials via env vars

**Gravidade:** BAIXA
**Arquivo alvo:** `Makefile`

**Problema:** O target `docker-run` passa `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, e `AWS_SESSION_TOKEN` como env vars para o container. Credentials em env vars podem aparecer em process listings.

**Requisito:** Substituir por mount read-only do diretório `~/.aws/`:
```makefile
.PHONY: docker-run
docker-run: ## Run a job inside the local Docker container
	$(DOCKER) run --rm \
		-e ENV=local \
		-e AWS_REGION=$(AWS_REGION) \
		-v $(HOME)/.aws:/root/.aws:ro \
		-v $(PWD)/src:/app/src \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		$(PYTHON) src/jobs/$(JOB)
```

**Critério de aceite:** O target `docker-run` não passa credentials como env vars. Usa mount de `~/.aws/` para autenticação.

---

### P3-03 — Step Functions: ASL Dinâmico

**Gravidade:** BAIXA
**Arquivo alvo:** `infrastructure/modules/stepfunction_pipeline/main.tf`, `asl.json`

**Problema:** O `asl.json` atual é um placeholder genérico (2 estados `Pass` sem lógica real). O input `glue_job_names` é declarado como "unused". Todo pipeline criado terá exatamente a mesma state machine inútil.

**Requisito:** Gerar o ASL definition dinamicamente a partir da lista de `glue_job_names`, criando estados `StartJobRun` encadeados.

**Referência de implementação:**
```terraform
variable "glue_job_names" {
  description = "Ordered list of Glue job names to execute sequentially."
  type        = list(string)
}

locals {
  # Build sequential states from job names
  states = { for i, name in var.glue_job_names :
    "Run_${replace(name, "-", "_")}" => {
      Type     = "Task"
      Resource = "arn:aws:states:::glue:startJobRun.sync"
      Parameters = {
        JobName = name
      }
      Next = i < length(var.glue_job_names) - 1 ? "Run_${replace(var.glue_job_names[i + 1], "-", "_")}" : "PipelineEnd"
    }
  }

  full_definition = {
    Comment = "Auto-generated pipeline"
    StartAt = length(var.glue_job_names) > 0 ? "Run_${replace(var.glue_job_names[0], "-", "_")}" : "PipelineEnd"
    States = merge(local.states, {
      PipelineEnd = {
        Type = "Succeed"
      }
    })
  }
}

resource "aws_sfn_state_machine" "this" {
  name       = var.pipeline_name
  role_arn   = var.role_arn
  definition = jsonencode(local.full_definition)
  # ... demais configs
}
```

**Critério de aceite:** O módulo gera um pipeline funcional a partir de `glue_job_names`. O arquivo `asl.json` pode ser removido. Pipelines existentes (exemplo: `test02/pipelines.tf`) continuam funcionando.

---

## Ordem de implementação sugerida

1. **P0-01** — S3 HTTPS enforcement (segurança crítica, change isolado)
2. **P0-02** — SHA pinning nas Actions (segurança crítica, change isolado)
3. **P1-04** — Remover Internet Gateway (rápido, reduz superfície)
4. **P1-05** — Restringir egress dos Security Groups
5. **P1-01** — VPC Flow Logs
6. **P1-02** — S3 Access Logging (depende de novo bucket)
7. **P1-03** — KMS CMK (impacta módulo S3 + IAM de todos os projetos)
8. **P2-01** — Refatorar workflows (alta economia de manutenção)
9. **P2-03** — Terraform validate para projects
10. **P2-04** + **P2-05** — Remoção de código morto
11. **P2-06** — Wheel versioning
12. **P3-01** a **P3-03** — Itens baixa prioridade

---

## Regras Gerais

- Manter compatibilidade com a arquitetura existente (remote state, auto-discovery, plug-and-play).
- Toda alteração em módulos Terraform deve ser refletida nos projetos que os usam (se necessário).
- Novos outputs do foundation devem ser re-exportados em `environments/*/outputs.tf`.
- Não alterar `setup/domain.json`.
- Manter os comentários/headers padronizados (estilo `# ─── Section Name ───`).
- Testar `terraform validate` e `terraform fmt -check` após cada alteração.
