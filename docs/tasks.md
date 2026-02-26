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
- [Data Engineering / Foundation Library](#data-engineering--foundation-library)

---

## SecOps

Tasks related to IAM, network security, encryption, supply chain security, and compliance.

---

### P0-01- SFN Execution Role: CloudWatch Logs Wildcard

| Field | Value |
|---|---|
| **Severity** | CRITICAL |
| **Status** | done |
| **Files** | `infrastructure/baseline/iam_orchestration.tf` |

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
| **Status** | done |
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
| **Status** | done |
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
| **Status** | done |
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

1. **Baseline job**- `terraform apply` on shared infrastructure (IAM, VPC, S3, KMS).
2. **Artifacts job**- `s3 cp` and `s3 sync` to upload wheel and job scripts.
3. **Deploy-projects job**- `terraform apply` per project (Glue jobs, tables, optimizers).

This violates least privilege: the role that applies Terraform to baseline (and therefore can modify IAM, KMS, VPC) should not also have S3 write access for artifact uploads, and vice versa.

#### Solution

Create three dedicated CI/CD IAM roles per account:

| Role Name | Permissions | Used By |
|---|---|---|
| `ci-terraform-baseline-<env>` | Full Terraform apply on baseline resources | `baseline` job |
| `ci-artifacts-<env>` | `s3:PutObject`, `s3:GetObject` on `{artifacts_bucket}/*` only | `artifacts` job |
| `ci-terraform-projects-<env>` | Terraform apply scoped to project-level resources (Glue, SFN, limited IAM) | `deploy-projects` job |

Update `_deploy.yml` to accept three separate role ARN inputs and `deploy-*.yml` to pass the correct ARN per role. Add three secrets per environment: `AWS_ROLE_ARN_FOUNDATION_<ENV>`, `AWS_ROLE_ARN_ARTIFACTS_<ENV>`, `AWS_ROLE_ARN_PROJECTS_<ENV>`.

---

### P0-03- Local Dev: Guard Against Accidental Production Credential Use

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Status** | open |
| **Files** | `dp_foundation/config/settings.py (in org-data-platform-foundation repo)`, `setup/bootstrap.sh` |

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

### P0-DEV-04- Documentation API Signatures Do Not Match Code

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **Status** | open |
| **Files** | `docs/adding-a-job.md` |

#### Problem

The example job template in `adding-a-job.md` uses function signatures that **do not exist** in the actual codebase:

```python
# In the docs (WRONG):
df = read_iceberg(spark, catalog_db=cfg["refined_db"], table="<source>")
write_iceberg(df=result, path=f"s3://...", catalog_db=cfg["curated_db"], table="<target>", mode="append")
```

The actual signatures in `dp_foundation/io/readers.py` and `dp_foundation/io/writers.py` are:

```python
# Actual code:
df = read_iceberg(spark, table="glue_catalog.{db}.{table}")
write_iceberg(df=result, table="glue_catalog.{db}.{table}", mode="append")
```

Additionally, the config keys used in the docs (`refined_db`, `curated_db`) do not exist in `get_config()` output. The correct keys are `iceberg_database_refined` and `iceberg_database_curated`.

A developer following this documentation will write code that fails immediately.

#### Solution

Update the example in `docs/adding-a-job.md` to match the actual API:

```python
from dp_foundation.spark.session import get_spark
from dp_foundation.config.settings import get_config
from dp_foundation.io.readers import read_iceberg
from dp_foundation.io.writers import write_iceberg
from dp_foundation.logging.logger import get_logger


def main() -> None:
    spark = get_spark(app_name="<project>-<name>")
    cfg = get_config()
    log = get_logger(__name__)

    log.info("Starting <name> job")

    # ── Extract ──────────────────────────────────
    df = read_iceberg(spark, f"glue_catalog.{cfg['iceberg_database_refined']}.<source>")

    # ── Transform ────────────────────────────────
    result = df  # your PySpark transformations here

    # ── Load ─────────────────────────────────────
    write_iceberg(
        df=result,
        table=f"glue_catalog.{cfg['iceberg_database_curated']}.<target>",
        mode="append",
    )

    log.info("<name> job complete")
    spark.stop()
```

Also remove `import sys` from the example since it is unused.

---

### P0-DEV-05- Makefile `WHEEL_NAME` Still Uses Removed Legacy Wheel Alias

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Status** | open |
| **Files** | `Makefile` |

#### Problem

The Makefile defines `WHEEL_NAME := data_platform_foundation-{version}-py3-none-any.whl` and uses it in the `upload-wheel` target. The CI/CD pipeline (`_deploy.yml`) removed the legacy alias as part of the security hardening sprint (completed in Phase 2) and now uploads only versioned wheels (`data_platform_foundation-{version}-py3-none-any.whl`).

The Makefile's `upload-wheel` target therefore uploads a wheel with a different filename than what the CI pipeline uses, creating inconsistency between local and CI deployments.

#### Solution

1. Update the Makefile to derive the wheel filename dynamically:

   ```makefile
   .PHONY: upload-wheel
   upload-wheel: build ## Build and upload wheel to S3
   	WHEEL=$$(ls $(WHEEL_DIR)/*.whl | head -1) && \
   	aws s3 cp "$$WHEEL" \
   		"s3://$(DOMAIN_ABBR)-artifacts-$(ACCOUNT_ID)-$(ENVIRONMENT)/wheels/$${WHEEL##*/}"
   ```

2. Remove the `WHEEL_NAME` variable entirely since it's no longer used.

3. Ensure consistency with the CI pipeline's upload path (`wheels/` prefix).

---

### P0-DEV-06- `creating-a-project.md` Contains Stale References

| Field | Value |
|---|---|
| **Severity** | LOW |
| **Status** | open |
| **Files** | `docs/creating-a-project.md` |

#### Problem

The project creation checklist in `creating-a-project.md` includes the item:

> - [ ] Module block added to `infrastructure/projects/main.tf`

This file does not exist. Projects are independent Terraform root modules- there is no central `main.tf` file that enumerates projects. Also, the checklist mentions `optimizers.tf` as requiring one optimizer per Iceberg table, but optimizers are now bundled automatically inside the `glue_iceberg_table` module.

#### Solution

1. Remove the line "Module block added to `infrastructure/projects/main.tf`" from the checklist.
2. Update the `optimizers.tf` checklist item to note that optimizers are created automatically by the Iceberg table module and that `optimizers.tf` is kept empty by convention.
3. Add a checklist item for creating the `src/jobs/<name>/` directory (aligns with P0-04).

---

## Platform / DataOps

Tasks related to the developer platform, project onboarding, data governance, and template completeness.

---

### P0-06- Glue Job Arguments Not Bridged to Environment Variables

| Field | Value |
|---|---|
| **Severity** | CRITICAL |
| **Status** | done |
| **Files** | `dp_foundation/config/settings.py (in org-data-platform-foundation repo)`, `dp_foundation/spark/session.py (in org-data-platform-foundation repo)`, `src/jobs/**/*.py` |

#### Problem

The `--ENV` default argument set in Glue job Terraform definitions (`default_arguments = { "--ENV" = var.environment }`) is passed to the job via `sys.argv`, which is how AWS Glue delivers custom parameters. However, `settings.py` reads the environment via `os.getenv("ENV")` and `session.py` uses the same mechanism in `_is_local()`. AWS Glue does **not** automatically set custom `--arguments` as OS environment variables- they are only accessible through `sys.argv` or `awsglue.utils.getResolvedOptions`.

This means that when a job runs in AWS Glue:

1. `os.getenv("ENV")` returns `None` → defaults to `"local"`.
2. `_is_local()` returns `True` → `get_spark()` attempts to build a **local** PySpark session instead of reusing the Glue-managed session.
3. `get_config()` resolves `env=local` → bucket names use the `-local` suffix instead of the correct environment suffix (e.g. `-dev`).

**All deployed jobs would either crash or silently read/write wrong S3 paths.**

#### Solution

Create a lightweight argument bridge in `dp_foundation` that parses `sys.argv` for Glue-style `--KEY value` pairs **without importing `awsglue`**, and inject them as environment variables before any other module consumes them. This preserves the "no `awsglue` imports" principle.

1. **Create `dp_foundation/config/args.py`** (in `org-data-platform-foundation` repo):

   ```python
   """Bridge AWS Glue job arguments (sys.argv) to environment variables.

   AWS Glue passes custom arguments as --KEY value pairs in sys.argv.
   This module parses them and sets them as OS environment variables
   so that settings.py and session.py can read them transparently.

   Must be imported BEFORE settings.py (handled by dp_foundation.__init__).
   """
   import os
   import sys

   _GLUE_ARG_PREFIX = "--"

   def bridge_glue_args() -> None:
       args = sys.argv[1:]
       i = 0
       while i < len(args):
           key = args[i]
           if key.startswith(_GLUE_ARG_PREFIX) and i + 1 < len(args):
               env_key = key.lstrip("-")
               value = args[i + 1]
               # Only set if not already in the environment
               if env_key not in os.environ:
                   os.environ[env_key] = value
               i += 2
           else:
               i += 1

   bridge_glue_args()
   ```

2. **In `dp_foundation/__init__.py`**, import the bridge **before** other modules:

   ```python
   import dp_foundation.config.args  # noqa: F401  # must be first
   from dp_foundation.config.settings import get_config
   from dp_foundation.logging.logger import get_logger
   from dp_foundation.spark.session import get_spark
   ```

3. **Add unit tests** to verify that `--ENV dev --CUSTOM_VAR value` pairs in `sys.argv` are correctly bridged.

4. **Update `docs/adding-a-job.md`** to document that Glue `default_arguments` keys (without the `--` prefix) become available as both environment variables and `get_config()` keys at runtime.

#### References

- AWS Documentation: [Accessing Parameters](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-api-crawler-pyspark-extensions-get-resolved-options.html)
- This is a blocking issue- the template cannot function in AWS Glue without this fix.

---

### P0-07- Missing VPC Endpoints for STS and CloudWatch Logs

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **Status** | done |
| **Files** | `infrastructure/baseline/subnets.tf`, `dp_foundation/config/settings.py (in org-data-platform-foundation repo)` |

#### Problem

The VPC has only two endpoints: S3 (Gateway) and Glue API (Interface). The private subnets have no NAT gateway and no internet gateway- by design, all traffic must flow through VPC endpoints.

`settings.py` calls `boto3.client("sts").get_caller_identity()` at module import time to resolve the AWS account ID for bucket naming. Without an STS VPC endpoint, this call will **timeout** (default ~60 seconds), and fall back to an empty string. This causes all dynamically built bucket names to be malformed (missing the account ID segment).

Additionally, Glue workers need to send execution logs to CloudWatch Logs. While Glue manages some logging internally, the custom structured logging via `dp_foundation.logging.logger` writes to `stderr` which Glue forwards to CloudWatch- but any explicit `boto3` CloudWatch Logs calls from the `dp_foundation` library or future extensions would also fail.

#### Solution

1. **Add an STS Interface VPC endpoint** in `subnets.tf`:

   ```hcl
   resource "aws_vpc_endpoint" "sts" {
     vpc_id              = aws_vpc.main.id
     service_name        = "com.amazonaws.${var.aws_region}.sts"
     vpc_endpoint_type   = "Interface"
     subnet_ids          = aws_subnet.private[*].id
     private_dns_enabled = true
     security_group_ids  = [aws_security_group.glue_endpoint.id]

     tags = merge(local.common_tags, {
       Name = "${var.domain_abbr}-vpce-sts-${var.env}"
     })
   }
   ```

2. **Add a CloudWatch Logs Interface VPC endpoint** (for future-proofing and explicit log API calls):

   ```hcl
   resource "aws_vpc_endpoint" "logs" {
     vpc_id              = aws_vpc.main.id
     service_name        = "com.amazonaws.${var.aws_region}.logs"
     vpc_endpoint_type   = "Interface"
     subnet_ids          = aws_subnet.private[*].id
     private_dns_enabled = true
     security_group_ids  = [aws_security_group.glue_endpoint.id]

     tags = merge(local.common_tags, {
       Name = "${var.domain_abbr}-vpce-logs-${var.env}"
     })
   }
   ```

3. Optionally, refactor `settings.py` to avoid the STS call entirely (see P0-PLAT-06).

#### References

- AWS Documentation: [VPC Endpoints for AWS STS](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_sts_vpce.html)
- The STS Interface endpoint has per-hour and per-GB costs (~$7.20/month per AZ). Budget accordingly.

---

### P0-08- `.env` File Generated But Never Loaded

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **Status** | done |
| **Files** | `setup/bootstrap.sh`, `dp_foundation/config/settings.py (in org-data-platform-foundation repo)`, `Makefile`, `pyproject.toml` |

#### Problem

`bootstrap.sh` generates a `.env` file with `ENV=local`, `AWS_REGION`, `AWS_ACCOUNT_ID`, and other configuration values. However, there is **no mechanism to load this file**:

- `python-dotenv` is not a project dependency.
- `settings.py` does not load `.env`.
- `make run-local` does not `source .env` before invoking the job.
- `make docker-run` does not pass `--env-file .env`.

Without a loading mechanism, the generated `.env` has no effect, and environment variables like `AWS_ACCOUNT_ID` (needed for bucket name resolution) are never set.

#### Solution

1. **Add `python-dotenv`** to `pyproject.toml` dependencies:

   ```toml
   dependencies = [
       "pyspark>=3.5,<3.6",
       "boto3>=1.35",
       "python-dotenv>=1.0",
   ]
   ```

2. **Load `.env` in `settings.py`** at module level (before `_resolve_account_id`):

   ```python
   from dotenv import load_dotenv
   load_dotenv()  # loads .env from CWD or parent directories
   ```

3. **Alternatively** (if adding a dependency is undesirable), load `.env` in the `Makefile`:

   ```makefile
   .PHONY: run-local
   run-local: ## Run a job locally
   	set -a && source .env && set +a && ENV=local $(PYTHON) src/jobs/$(JOB)
   ```

   And in `docker-run`:

   ```makefile
   .PHONY: docker-run
   docker-run:
   	$(DOCKER) run --rm --env-file .env ...
   ```

4. **Document** in `setup/README.md` that after bootstrap, developers should either source `.env` manually or rely on the Makefile targets.

---

### P0-09- Step Functions Pipeline: No Retry or Error Handling

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Status** | done |
| **Files** | `infrastructure/modules/stepfunction_pipeline/main.tf` |

#### Problem

The dynamically generated ASL definition for Step Functions pipelines produces sequential tasks with no `Retry` or `Catch` blocks. In production, Glue jobs can fail due to transient issues (throttling, spot instance reclaim, S3 eventual consistency). Without retry logic, a single transient failure stops the entire pipeline immediately, requiring manual re-execution.

AWS [recommends](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-error-handling.html) adding Retry with exponential backoff as a best practice for all Task states.

#### Solution

1. **Add Retry and Catch blocks** to each generated state:

   ```hcl
   locals {
     states = { for i, name in var.glue_job_names :
       "Run_${local.sanitised_names[i]}" => jsondecode(jsonencode({
         Type     = "Task"
         Resource = "arn:aws:states:::glue:startJobRun.sync"
         Parameters = { JobName = name }
         Retry = [{
           ErrorEquals     = ["States.ALL"]
           IntervalSeconds = 60
           MaxAttempts     = var.max_retries
           BackoffRate     = 2.0
         }]
         Catch = [{
           ErrorEquals = ["States.ALL"]
           Next        = "PipelineFailed"
         }]
         Next = i < length(var.glue_job_names) - 1 ? "Run_${local.sanitised_names[i + 1]}" : "PipelineSucceeded"
         # ... conditional End handling
       }))
     }
   }
   ```

2. **Add terminal states** (`PipelineSucceeded`, `PipelineFailed`) for clean reporting.

3. **Add variables** for `max_retries` (default: 2) and `backoff_seconds` (default: 60) to make retry behaviour configurable per pipeline.

4. Optionally, add an SNS notification step on failure (integrates with P0-10).

---

### P0-10- No Observability or Alerting Infrastructure

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Status** | done |
| **Files** | `infrastructure/baseline/`, `infrastructure/modules/stepfunction_pipeline/main.tf` |

#### Problem

There are no CloudWatch Alarms, SNS topics, or EventBridge rules configured anywhere in the template. When a Glue job fails, a Step Functions pipeline errors out, or an optimizer encounters issues, **no one is notified**. In production, this means failures can go undetected for hours or days.

For a Data Mesh domain handling data products with SLAs, this is a critical operational gap.

#### Solution

1. **Create a baseline-level SNS topic** for pipeline alerts:

   ```hcl
   resource "aws_sns_topic" "pipeline_alerts" {
     name              = "${var.domain_abbr}-pipeline-alerts-${var.env}"
     kms_master_key_id = aws_kms_key.data_lake.arn
     tags              = local.common_tags
   }
   ```

2. **Add an EventBridge rule** to capture Step Functions execution failures:

   ```hcl
   resource "aws_cloudwatch_event_rule" "sfn_failure" {
     name = "${var.domain_abbr}-sfn-failure-${var.env}"
     event_pattern = jsonencode({
       source      = ["aws.states"]
       detail-type = ["Step Functions Execution Status Change"]
       detail      = { status = ["FAILED", "TIMED_OUT", "ABORTED"] }
     })
   }

   resource "aws_cloudwatch_event_target" "sfn_failure_sns" {
     rule      = aws_cloudwatch_event_rule.sfn_failure.name
     target_id = "sns"
     arn       = aws_sns_topic.pipeline_alerts.arn
   }
   ```

3. **Add Glue job failure EventBridge rule** similarly for `"detail-type": ["Glue Job State Change"]` with `"state": ["FAILED", "TIMEOUT", "ERROR"]`.

4. **Export the SNS topic ARN** from baseline outputs so projects can subscribe additional targets (email, Slack webhook via Lambda, PagerDuty).

5. **Document** the alerting setup and how teams should subscribe to the topic.

---

### P0-04- Template Completeness and `project.json` Metadata

| Field | Value |
|---|---|
| **Severity** | LOW |
| **Status** | done |
| **Files** | `infrastructure/projects/_template/`, `src/jobs/` |

#### Problem 1: `project.json` lacks governance metadata

The current `project.json` template contains only `{"name": "REPLACE_ME"}`. A production-ready Data Mesh contract should include governance metadata that enables data discovery, classification, and SLA enforcement.

#### Problem 2: No `src/jobs/_template/` directory

Creating a new project currently requires a developer to know they need to manually create `src/jobs/<project_name>/`. This breaks the plug-and-play principle- one copy operation should deliver everything.

#### Problem 3: `make new-project` does not create the jobs directory

The `new-project` Makefile target only copies the Terraform template. It does not scaffold `src/jobs/<name>/`.

#### Solution

1. **Expand `project.json`** with optional governance fields:

   ```json
   {
     "name": "REPLACE_ME",
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
| **Status** | done |
| **Files** | `infrastructure/projects/*/jobs.tf`, `.github/workflows/_deploy.yml` |

#### Problem

The `data_platform_foundation-{version}-py3-none-any.whl` wheel alias upload was removed from `_deploy.yml` as part of the security hardening sprint (non-deterministic wheel version). Any Glue job Terraform definition that still references the old wheel filename in its `--extra-py-files` argument will fail at runtime.

#### Solution

1. Update all `jobs.tf` files to reference the versioned wheel pattern, e.g.:

   ```hcl
   extra_py_files = "s3://${local.baseline.s3_artifacts_bucket}/wheels/data_platform_foundation-${var.wheel_version}-py3-none-any.whl"
   ```

2. Pass `wheel_version` as a Terraform variable (set from `TF_VAR_wheel_version` in CI alongside the existing traceability vars).

3. Alternatively, store the current wheel path in SSM Parameter Store after upload and read it as a `data.aws_ssm_parameter` in Terraform- decoupling the wheel version from the Terraform apply step.

---

## Data Engineering / Foundation Library

Tasks related to the shared `dp_foundation` Python library, data quality, job patterns, and test coverage.

---

### P0-ENG-01- `settings.py` Module-Level Side Effects (STS Call at Import Time)

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Status** | open |
| **Files** | `dp_foundation/config/settings.py (in org-data-platform-foundation repo)` |

#### Problem

`_resolve_account_id()`, `_load_domain()`, and the subsequent construction of `_DEFAULTS` all execute as **module-level code** when `settings.py` is first imported. This means:

1. **Every `import dp_foundation.config.settings`** triggers an STS network call (or catches the timeout/exception). In a test suite with 20+ files, this adds significant latency.
2. The values are computed once and **cannot be changed** without reloading the module, making tests brittle (`monkeypatch.setenv` after import has no effect on the cached `_ACCOUNT_ID`).
3. An unreachable STS endpoint (e.g. inside a VPC without the endpoint, or offline) silently falls back to `""`, producing subtly wrong bucket names rather than an explicit error.

#### Solution

Refactor to lazy initialisation. Replace the module-level constants with functions that compute and cache on first call:

```python
import functools

@functools.lru_cache(maxsize=1)
def _get_account_id() -> str:
    acct = os.getenv("AWS_ACCOUNT_ID", "")
    if acct:
        return acct
    try:
        import boto3
        return boto3.client("sts").get_caller_identity()["Account"]
    except Exception:
        return ""

@functools.lru_cache(maxsize=1)
def _get_domain() -> dict[str, str]:
    # ... same logic, but only runs when first called
```

This preserves the current behaviour for jobs (which call `get_config()` early) but eliminates the import-time side effect, allowing tests to patch environment variables before the first call.

Also expose a `clear_cache()` or `_reset()` helper for tests:

```python
def _reset():
    _get_account_id.cache_clear()
    _get_domain.cache_clear()
```

---

### P0-ENG-02- `write_iceberg()` `sort_by` Parameter Does Not Sort Data

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Status** | open |
| **Files** | `dp_foundation/io/writers.py (in org-data-platform-foundation repo)` |

#### Problem

The `sort_by` parameter in `write_iceberg()` is implemented as:

```python
if sort_by:
    writer = writer.tableProperty("write.sort-order", ",".join(sort_by))
```

`writer.tableProperty()` sets an Iceberg table property on the metadata, it does **not** sort the data being written. The Spark `writeTo` API does not support specifying sort order per-write through `tableProperty`. The actual data files will remain unsorted regardless of this setting.

To achieve sorted writes, the data must either be sorted in the DataFrame before writing, or the table's sort order must be defined via DDL (`ALTER TABLE ... WRITE ORDERED BY ...`), which causes Iceberg to sort internally on subsequent writes.

#### Solution

Option A (recommended for simplicity): Sort the DataFrame before writing:

```python
if sort_by:
    df = df.sortWithinPartitions(*sort_by) if partition_by else df.orderBy(*sort_by)
```

Option B (recommended for Iceberg-native sort): Set the sort order at table creation time via `create_table_if_not_exists()` in `catalog.py` and remove `sort_by` from the write function. Table-level sort order is then respected automatically by Iceberg on every write.

Document in the function docstring which approach is used and why.

---

### P0-ENG-04- No Schema Validation in `DataQualityChecker`

| Field | Value |
|---|---|
| **Severity** | LOW |
| **Status** | open |
| **Files** | `dp_foundation/quality/checks.py (in org-data-platform-foundation repo)` |

#### Problem

The `DataQualityChecker` supports null checks, uniqueness, value sets, and range validations, but it has no check for **schema conformance**: verifying that the DataFrame has the expected columns with the expected types. Schema drift is one of the most common causes of silent data corruption in data pipelines, and a schema validation check is fundamental for a platform template.

#### Solution

Add a `schema_match()` method:

```python
def schema_match(
    self,
    expected: dict[str, str],
    allow_extra_columns: bool = True,
) -> DataQualityChecker:
    """Assert that the DataFrame schema matches the expected column→type mapping.

    Parameters
    ----------
    expected:
        Dict of {column_name: spark_type_string}, e.g. {"id": "string", "amount": "decimal(18,2)"}.
    allow_extra_columns:
        If False, fail when the DataFrame has columns not in `expected`.
    """
    self._checks.append(("schema_match", (expected, allow_extra_columns)))
    return self
```

Implement the check in `run()`:

```python
elif check_type == "schema_match":
    expected, allow_extra = params
    actual = {f.name: f.dataType.simpleString() for f in self._df.schema.fields}
    missing = {k: v for k, v in expected.items() if k not in actual}
    type_mismatches = {k: (expected[k], actual[k]) for k in expected if k in actual and actual[k] != expected[k]}
    extra = set(actual) - set(expected) if not allow_extra else set()
    passed = not missing and not type_mismatches and not extra
    detail_parts = []
    if missing:
        detail_parts.append(f"missing: {list(missing.keys())}")
    if type_mismatches:
        detail_parts.append(f"type mismatches: {type_mismatches}")
    if extra:
        detail_parts.append(f"unexpected: {list(extra)}")
    result = CheckResult(
        name="schema_match", passed=passed, detail="; ".join(detail_parts)
    )
```

---

### P0-ENG-05- Test Coverage: No SparkSession Fixture or Foundation Module Tests

| Field | Value |
|---|---|
| **Severity** | LOW |
| **Status** | open |
| **Files** | `tests/conftest.py`, `tests/` |

#### Problem

The test suite has no SparkSession fixture and only tests `config` and `logging`. The `dp_foundation` modules that handle actual data - `readers.py`, `writers.py`, `quality/checks.py`, `iceberg/catalog.py` - have **zero unit tests**. The `conftest.py` file is empty.

The `test_jobs.py` file is excellent for structural validation (syntax, imports, main guard), but it does not test any job logic.

For a production template used by large organisations, the test scaffolding should demonstrate how to test data transformations so that teams copying the template inherit a healthy testing culture.

#### Solution

1. **Add a SparkSession fixture** to `conftest.py`:

   ```python
   import pytest
   from pyspark.sql import SparkSession

   @pytest.fixture(scope="session")
   def spark():
       session = (
           SparkSession.builder
           .master("local[1]")
           .appName("unit-tests")
           .config("spark.sql.shuffle.partitions", "1")
           .config("spark.ui.enabled", "false")
           .getOrCreate()
       )
       yield session
       session.stop()
   ```

2. **Add tests for `quality/checks.py`**:
   - Test each check type (not_null, unique, value_in_set, min_value, max_value, row_count_min).
   - Test `assert_all_passed()` raises `DataQualityError` on failure.

3. **Add basic tests for `readers.py` and `writers.py`**:
   - Write and read Parquet in a temp directory.
   - Test `write_iceberg` mode validation and partition handling.

4. **Add test for `catalog.py`**:
   - Test DDL generation (verify the SQL string produced by `create_table_if_not_exists`).

5. **Document** the test structure in a short `tests/README.md` to guide teams on what and how to test.

---

## Completed Tasks

| ID | Title | Completed |  
|---|---|---|
| P0-06 | Glue job arguments bridged to environment variables (`dp_foundation.config.args`) | Phase 3 sprint |
| P0-07 | VPC endpoints added for STS and CloudWatch Logs | Phase 3 sprint |
| P0-08 | `.env` file loaded via `python-dotenv` + Makefile sourcing | Phase 3 sprint |
| P0-09 | Step Functions pipeline: Retry, Catch, and terminal states added | Phase 3 sprint |
| P0-10 | Observability: SNS topic + EventBridge rules for SFN/Glue failures | Phase 3 sprint |
| P0-04 | Template completeness: `project.json` governance fields, `job_example.py`, `make new-project` scaffolds jobs dir | Phase 3 sprint |
| P0-05 | Wheel reference updated to versioned `data_platform_foundation` pattern, `WHEEL_NAME` removed from Makefile | Phase 3 sprint |
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
|- | CI/CD: legacy wheel alias removed, versioned `data_platform_foundation` wheel only | Phase 2 sprint |
|- | Terraform plan PR: truncation (`\| head -N`) removed | Phase 2 sprint |
|- | Traceability tags: `git_sha`, `deployed_by`, `repository` on all resources | Phase 2 sprint |
