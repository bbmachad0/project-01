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
| `core` | `src/core/**`, `pyproject.toml` | Wheel rebuild + upload; **all** projects re-deployed |
| `jobs` | `src/jobs/**` | Script upload to S3; **all** projects re-deployed |
| `foundation_infra` | `infrastructure/foundation/**`, `infrastructure/environments/**`, `infrastructure/modules/**`, `setup/domain.json` | Foundation apply + **all** projects re-applied |
| `projects_infra` | `infrastructure/projects/**` | **Only changed** projects re-applied |

This avoids rebuilding the wheel when only a job script changed, and avoids
running Terraform when only Python code changed.

Additionally, the `discover` job compares `project.json` files between `HEAD~1`
and `HEAD` to detect **removed projects**- directories that existed in the
previous commit but no longer exist. These are passed to a dedicated
`destroy-projects` job (see [Removing a Project](#removing-a-project) below).

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

The deploy wrappers call the reusable `_deploy.yml` workflow, which runs a
strict four-phase pipeline:

```
┌─────────────────────────────────┐
│ 1. Detect Changes + Discover    │  paths-filter + git diff
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│ 2. Foundation Terraform Apply   │  S3, IAM, VPC, KMS, Glue DBs
└──────────────┬──────────────────┘
               │
       ┌───────┴────────┐
       │                │
┌──────▼──────┐  ┌──────▼───────────────┐
│ 3. Artifacts│  │ 3. Destroy Projects  │  (parallel)
│   Upload    │  │   terraform destroy  │
└──────┬──────┘  └──────────────────────┘
       │
┌──────▼──────────────────────────┐
│ 4. Deploy Projects              │  terraform apply (parallel matrix)
└─────────────────────────────────┘
```

**Phase 1- Detect Changes + Discover:**
- `paths-filter` classifies what changed (core, jobs, foundation, projects).
- The `discover` job builds two matrices: projects to **deploy** and projects to **destroy**.

**Phase 2- Foundation:**
- `terraform apply` on `infrastructure/environments/<env>/` (shared infra).

**Phase 3a- Artifacts Upload** (conditional on `core` / `jobs` changes):
- Wheel build + versioned upload (only if `src/core/**` changed).
- Script sync via `s3 sync --delete` (only if `src/jobs/**` changed).

**Phase 3b- Destroy Removed Projects** (runs in parallel with artifacts):
- For each removed project, restores its Terraform files from `HEAD~1`.
- Runs `terraform destroy` to tear down all AWS resources.
- See [Removing a Project](#removing-a-project) for details.

**Phase 4- Deploy Projects:**
- `terraform apply` per project (parallel matrix, `fail-fast: false`).
- Only affected projects are included- either changed ones, or all of them
  if shared components (core, jobs, foundation, modules) changed.

This ordering guarantees: S3 buckets exist → artifacts are uploaded →
Glue jobs can reference them. Destroy runs independently since it only
tears down resources, not create them.

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

## Selective Project Deployment

Not every push deploys every project. The `discover` job determines the
minimal set of projects that need re-applying:

| What changed | Projects deployed |
|---|---|
| `src/core/**` or `pyproject.toml` | **All**- new wheel affects every job |
| `src/jobs/**` | **All**- scripts are synced globally |
| `infrastructure/foundation/**`, `modules/**`, `environments/**` | **All**- shared infra may affect any project |
| Only `infrastructure/projects/sales/` | **Only `sales`**- `git diff` scopes to changed dirs |
| Nothing relevant changed | **None**- entire deploy workflow is skipped |

---

## Removing a Project

The CI/CD pipeline is the **single source of truth** for all cloud mutations —
including resource teardown. When a project directory is deleted from the repo,
the `destroy-projects` job handles decommissioning automatically.

### How it works

1. The `discover` job compares `project.json` files between `HEAD~1` and
   `HEAD`. Any project present in `HEAD~1` but absent in `HEAD` is flagged
   as **removed**.
2. The `destroy-projects` job restores the deleted Terraform files via
   `git checkout HEAD~1 -- infrastructure/projects/<name>/`.
3. It reads the `slug` from the restored `project.json` to locate the
   correct remote state file in S3.
4. `terraform init` connects to the existing state, then
   `terraform plan -destroy` + `terraform apply` tears down all AWS
   resources managed by that project (Glue jobs, IAM roles, tables,
   optimizers, Step Functions pipelines).

### Step-by-step: decommission a project

```bash
# 1. Delete both the infrastructure and job directories
rm -rf infrastructure/projects/myproject
rm -rf src/jobs/myproject

# 2. Commit and push
git add -A
git commit -m "chore: remove myproject"
git push origin dev
```

The workflow will automatically:
- Run `terraform destroy` for the project (removing AWS resources).
- Remove job scripts from S3 (via `s3 sync --delete`).

### Important caveats

- **One concern per commit:** avoid deleting a project and making breaking
  changes to shared Terraform modules in the same commit. The destroy job
  restores `.tf` files from `HEAD~1` but uses the current `modules/`- if
  modules have incompatible changes, the destroy plan may fail. Do it in
  two sequential commits: destroy first, then refactor modules.

- **S3 data is not deleted:** `terraform destroy` removes Glue catalog
  entries, IAM roles, and jobs, but the underlying data objects in S3
  data buckets (raw/refined/curated) are **not** affected. S3 buckets
  have `prevent_destroy = true`. Manual cleanup of data prefixes is
  required if needed.

- **State file cleanup:** after a successful destroy, the Terraform state
  file remains in S3 (`projects/<slug>/terraform.tfstate`). It can be
  deleted manually once the teardown is confirmed.

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
