# CI/CD

All pipelines live in `.github/workflows/` and use **GitHub Actions**.

---

## Branch Strategy

```
feature/*  ──PR──▶  dev  ──PR──▶  int  ──PR──▶  main (prod)
                     │              │               │
                  Deploy Dev    Deploy Int     Deploy Prod
```

| Workflow | Trigger | Target |
|----------|---------|--------|
| `ci.yml` | Every push / PR | Lint, test, validate, build |
| `deploy-dev.yml` | Push to `dev` | Dev AWS account |
| `deploy-int.yml` | Push to `int` | Int AWS account |
| `deploy-prod.yml` | Push to `main` | Prod AWS account (manual approval) |

---

## Change Detection

Workflows use [`dorny/paths-filter@v3`](https://github.com/dorny/paths-filter)
to detect which components changed:

| Filter | Path pattern | What it triggers |
|--------|-------------|------------------|
| `core` | `src/core/**` | Wheel rebuild + upload |
| `jobs` | `src/jobs/**` | Script upload to S3 |
| `infra` | `infrastructure/**` | Terraform plan/apply |

This avoids rebuilding the wheel when only a job script changed, and avoids
running Terraform when only Python code changed.

---

## Pipeline Steps

### CI (`ci.yml`)

1. Checkout + read `domain.json`
2. Set up Python (version from `domain.json`)
3. Install dependencies (`pip install -e ".[dev]"`)
4. Lint (`ruff check`)
5. Type check (`mypy src/core/`)
6. Unit tests (`pytest`)
7. Terraform validate (all environments)
8. Build wheel (if `src/core/**` changed)

### Deploy (`deploy-{dev,int,prod}.yml`)

1. Checkout + read `domain.json`
2. Authenticate via OIDC
3. Detect changes (paths-filter)
4. Upload job scripts to S3 (if jobs changed)
5. Build + upload wheel to S3 (if core changed)
6. Terraform init + plan + apply (if infra changed)

---

## AWS Authentication - OIDC

No static credentials are stored. Each workflow assumes an IAM role via
[GitHub OIDC](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

### Required GitHub Secrets

| GitHub Environment | Secret | Value |
|--------------------|--------|-------|
| `dev` | `AWS_ROLE_ARN_DEV` | `arn:aws:iam::<dev-account>:role/<role-name>` |
| `int` | `AWS_ROLE_ARN_INT` | `arn:aws:iam::<int-account>:role/<role-name>` |
| `prod` | `AWS_ROLE_ARN_PROD` | `arn:aws:iam::<prod-account>:role/<role-name>` |

### IAM Trust Policy

The OIDC role in each AWS account needs a trust policy like:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:*"
        }
      }
    }
  ]
}
```

Replace `<account-id>`, `<org>`, and `<repo>` with your values. For production,
restrict `sub` to specific branches (e.g. `repo:<org>/<repo>:ref:refs/heads/main`).

---

## Terraform Backend

Each environment uses a partial S3 backend. The `setup/init-terraform.sh`
script generates `backend.conf` files from `domain.json`:

```
infrastructure/environments/dev/backend.conf
infrastructure/environments/int/backend.conf
infrastructure/environments/prod/backend.conf
```

CI workflows run `terraform init -backend-config=backend.conf` automatically.
