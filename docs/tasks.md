# Engineering Backlog

This document tracks open improvement tasks for the domain repository, organised by area of responsibility. Each task follows the format:

> **ID** | **Severity** | **Area** | **Status**

Severity levels: `CRITICAL` → `HIGH` → `MEDIUM` → `LOW`

Status: `open` | `in-progress` | `done`

---

## Table of Contents

- [SecOps](#secops)
- [DevOps / CI-CD](#devops--ci-cd)
- [Platform / DataOps](#platform--dataops)

---

## SecOps

Tasks related to IAM, network security, encryption, supply chain security, and compliance.

---

### P0-01- SFN Execution Role: CloudWatch Logs Wildcard

| Field | Value |
|---|---|
| **Severity** | CRITICAL |
| **Status** | open |
| **Files** | `infrastructure/foundation/iam_orchestration.tf` |

#### Problem

The Step Functions execution role (`iam_orchestration.tf`) has a `CloudWatchLogs` statement that grants 8 log actions- including `logs:PutResourcePolicy` and `logs:DeleteLogDelivery`- against `resources = ["*"]`. This is a wildcard resource grant for sensitive log administration actions.

#### Solution

Split the `CloudWatchLogs` statement into two scoped statements:

1. **Operational actions** (`CreateLogGroup`, `CreateLogStream`, `PutLogEvents`, `DescribeLogStreams`):
   - Resources: `["arn:aws:logs:${region}:${account}:log-group:/aws/states/${domain_abbr}-*"]`

2. **Administrative actions** (`PutResourcePolicy`, `DescribeResourcePolicies`, `DeleteLogDelivery`, `GetLogRecord`):
   - Evaluate whether each action is truly needed by SFN at runtime.
   - If needed, scope to `["arn:aws:logs:${region}:${account}:log-group:*"]` at minimum.
   - Prefer deleting `PutResourcePolicy` and `DeleteLogDelivery` from the role entirely- these are typically one-time setup actions, not runtime requirements.

#### References

- AWS Documentation: [Step Functions IAM Policies](https://docs.aws.amazon.com/step-functions/latest/dg/security-iam.html)
- CIS AWS Benchmark 1.16: IAM policies should not allow full `*` privileges

---

### P0-SEC-02- Glue Job Role: `DescribeNetworkInterfaces` Still Uses Wildcard

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **Status** | open |
| **Files** | `infrastructure/modules/iam_glue_job/main.tf` |

#### Problem

The `EC2DescribeNetworking` statement in `iam_glue_job` uses `resources = ["*"]` for `ec2:DescribeSubnets`, `ec2:DescribeVpcs`, `ec2:DescribeSecurityGroups`, `ec2:DescribeNetworkInterfaces`, and `ec2:DescribeVpcEndpoints`. These Describe actions are [List-category API calls](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html) that do not support resource-level ARN scoping in IAM- AWS requires `"*"` for them. This is acceptable and documented behaviour.

#### Action

Add a comment in `iam_glue_job/main.tf` explicitly noting that `resources = ["*"]` on these Describe actions is **intentional and required by AWS**, not a misconfiguration. This prevents future reviewers from incorrectly flagging it as a finding.

---

### P0-SEC-03- Supply Chain: SBOM Generation and Pin Actions by Digest

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **Status** | open |
| **Files** | `.github/workflows/ci.yml`, `pyproject.toml` |

#### Problem

GitHub Actions `uses` references pin to mutable tags (e.g. `actions/checkout@v4`). A tag can be moved to point to a malicious commit. Python dependencies in `pyproject.toml` use version ranges, allowing supply chain attacks via compromised minor/patch releases.

#### Solution

1. **Pin GitHub Actions by commit SHA** instead of tag:

   ```yaml
   # Before
   - uses: actions/checkout@v4
   # After
   - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
   ```

   Use [`pin-github-action`](https://github.com/mheap/pin-github-action) to automate pinning.

2. **Generate an SBOM** as part of CI:

   ```bash
   pip install cyclonedx-bom
   cyclonedx-py environment -o sbom.json
   ```

   Attach the SBOM as a CI artefact and optionally publish to [DependencyTrack](https://dependencytrack.org/).

3. **Dependabot**- add `.github/dependabot.yml` to automate Python dependency and GitHub Actions update PRs:

   ```yaml
   version: 2
   updates:
     - package-ecosystem: "github-actions"
       directory: "/"
       schedule:
         interval: "weekly"
     - package-ecosystem: "pip"
       directory: "/"
       schedule:
         interval: "weekly"
   ```

---

### P0-SEC-04- Harden Bandit and Checkov: Remove Exit Codes Bypass

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Status** | open |
| **Files** | `.github/workflows/ci.yml` |

#### Problem

The `security-scan` CI job currently runs `bandit` with `--exit-zero` and `checkov` with `--soft-fail`. These flags make the tools report-only- findings never block a PR merge. This is acceptable as a bootstrap measure but must not become permanent.

#### Solution

1. Run the tools without bypass flags on a dev branch to establish a baseline.
2. Create suppressions (`.bandit` config or inline `# nosec` comments; `.checkov.yml` suppressions) for any accepted false positives.
3. Remove `--exit-zero` from `bandit` and `--soft-fail` from `checkov`.
4. Failing security scans should block PRs.

---

## DevOps / CI-CD

Tasks related to CI/CD pipeline reliability, security of the deployment process, and developer experience.

---

### P0-02- CI/CD: Separate IAM Roles per Responsibility

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **Status** | open |
| **Files** | `.github/workflows/_deploy.yml`, `.github/workflows/deploy-*.yml` |

#### Problem

The `_deploy.yml` reusable workflow uses a single `AWS_ROLE_ARN` for three distinctly different responsibilities:

1. **Foundation job**- `terraform apply` on shared infrastructure (IAM, VPC, S3, KMS).
2. **Artifacts job**- `s3 cp` and `s3 sync` to upload wheel and job scripts.
3. **Deploy-projects job**- `terraform apply` per project (Glue jobs, tables, optimizers).

This violates least privilege: the role that applies Terraform to foundation (and therefore can modify IAM, KMS, VPC) should not also have S3 write access for artifact uploads, and vice versa.

#### Solution

Create three dedicated CI/CD IAM roles per account:

| Role Name | Permissions | Used By |
|---|---|---|
| `ci-terraform-foundation-<env>` | Full Terraform apply on foundation resources | `foundation` job |
| `ci-artifacts-<env>` | `s3:PutObject`, `s3:GetObject` on `{artifacts_bucket}/*` only | `artifacts` job |
| `ci-terraform-projects-<env>` | Terraform apply scoped to project-level resources (Glue, SFN, limited IAM) | `deploy-projects` job |

Update `_deploy.yml` to accept three separate role ARN inputs and `deploy-*.yml` to pass the correct ARN per role. Add three secrets per environment: `AWS_ROLE_ARN_FOUNDATION_<ENV>`, `AWS_ROLE_ARN_ARTIFACTS_<ENV>`, `AWS_ROLE_ARN_PROJECTS_<ENV>`.

---

### P0-03- Local Dev: Guard Against Accidental Production Credential Use

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Status** | open |
| **Files** | `src/core/config/settings.py`, `setup/bootstrap.sh` |

#### Problem

When running jobs locally (`ENV=local`), `_resolve_account_id()` in `settings.py` calls `sts.get_caller_identity()` silently. If a developer has `AWS_PROFILE=prod` or their default profile points to the production account, local jobs will resolve production bucket names and potentially read/write production data without any warning.

#### Solution

1. **In `settings.py`**: Before making the STS call, check if `ENV=local` and emit a warning log showing which AWS account and profile will be used:

   ```python
   if env == "local":
       profile = os.environ.get("AWS_PROFILE", os.environ.get("AWS_DEFAULT_PROFILE", "default"))
       logger.warning(
           "Running in local mode using AWS profile '%s'. "
           "Ensure this is not a production account.", profile
       )
   ```

2. **In `bootstrap.sh`**: After the STS call, check the account alias or account ID against a known allowlist of non-production accounts and prompt the user to confirm if running against an unrecognised account.

3. **In `README.md` / `setup/README.md`**: Document the use of named AWS profiles per environment (`[profile dev]`, `[profile int]`, `[profile prod]` in `~/.aws/config`) and recommend setting `AWS_PROFILE=dev` before running local jobs.

---

## Platform / DataOps

Tasks related to the developer platform, project onboarding, data governance, and template completeness.

---

### P0-04- Template Completeness and `project.json` Metadata

| Field | Value |
|---|---|
| **Severity** | LOW |
| **Status** | open |
| **Files** | `infrastructure/projects/_template/`, `src/jobs/` |

#### Problem 1: `project.json` lacks governance metadata

The current `project.json` template contains only `{"slug": "REPLACE_ME"}`. A production-ready Data Mesh contract should include governance metadata that enables data discovery, classification, and SLA enforcement.

#### Problem 2: No `src/jobs/_template/` directory

Creating a new project currently requires a developer to know they need to manually create `src/jobs/<project_name>/`. This breaks the plug-and-play principle- one copy operation should deliver everything.

#### Problem 3: `make new-project` does not create the jobs directory

The `new-project` Makefile target only copies the Terraform template. It does not scaffold `src/jobs/<name>/`.

#### Solution

1. **Expand `project.json`** with optional governance fields:

   ```json
   {
     "slug": "REPLACE_ME",
     "data_owner": "team-name",
     "data_classification": "internal",
     "pii": false,
     "sla_tier": "standard",
     "team_email": "team@example.com"
   }
   ```

   All new fields should be optional with documented defaults.

2. **Create `src/jobs/_template/job_example.py`**- a fully commented job script following the standard `get_spark` / `get_config` / `get_logger` pattern, serving as a starting point for new jobs.

3. **Update `make new-project`** to also:
   - Create `src/jobs/<name>/` directory.
   - Copy `src/jobs/_template/job_example.py` as `src/jobs/<name>/job_example.py`.

4. **Update `docs/adding-a-job.md`** to document the new `project.json` fields and the complete end-to-end flow with the updated `make new-project` command.

---

### P0-05- Wheel Reference: Update Jobs After Removing `latest` Alias

| Field | Value |
|---|---|
| **Severity** | LOW |
| **Status** | open |
| **Files** | `infrastructure/projects/*/jobs.tf`, `.github/workflows/_deploy.yml` |

#### Problem

The `core-latest-py3-none-any.whl` alias upload was removed from `_deploy.yml` as part of the security hardening sprint (non-deterministic wheel version). Any Glue job Terraform definition that still references `core-latest-py3-none-any.whl` in its `--extra-py-files` argument will fail at runtime.

#### Solution

1. Update all `jobs.tf` files to reference the versioned wheel pattern, e.g.:

   ```hcl
   extra_py_files = "s3://${local.foundation.s3_artifacts_bucket}/core/core-${var.wheel_version}-py3-none-any.whl"
   ```

2. Pass `wheel_version` as a Terraform variable (set from `TF_VAR_wheel_version` in CI alongside the existing traceability vars).

3. Alternatively, store the current wheel path in SSM Parameter Store after upload and read it as a `data.aws_ssm_parameter` in Terraform- decoupling the wheel version from the Terraform apply step.

---

## Completed Tasks

| ID | Title | Completed |  
|---|---|---|
|- | EC2 CreateNetworkInterface scoped to subnet ARNs | Phase 2 sprint |
|- | VPC Flow Logs IAM policy scoped to log group ARN | Phase 2 sprint |
|- | KMS CMK explicit 3-statement key policy | Phase 2 sprint |
|- | S3 logs bucket policy conflict resolved (`create_bucket_policy` flag) | Phase 2 sprint |
|- | SFN pipeline log group KMS-encrypted | Phase 2 sprint |
|- | VPC flow log group KMS-encrypted | Phase 2 sprint |
|- | CI: `id-token: write` removed from global permissions | Phase 2 sprint |
|- | CI: `security-scan` job added (pip-audit + bandit + checkov) | Phase 2 sprint |
|- | CI/CD: `sed -i __init__.py` wrapped with `trap` for git restore | Phase 2 sprint |
|- | CI/CD: AWS Account ID masked with `::add-mask::` | Phase 2 sprint |
|- | CI/CD: `core-latest` wheel alias removed, versioned wheel only | Phase 2 sprint |
|- | Terraform plan PR: truncation (`\| head -N`) removed | Phase 2 sprint |
|- | Traceability tags: `git_sha`, `deployed_by`, `repository` on all resources | Phase 2 sprint |
