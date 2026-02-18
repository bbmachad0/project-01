# Creating a Project

A **project** is an isolated unit of work within the domain - it owns its
tables, Glue jobs, optimizers, and pipelines. Each project lives in two places:

- **Infrastructure** → `infrastructure/projects/<name>/`
- **Job scripts** → `src/jobs/<name>/`

---

## Step-by-step

### 1. Copy the template

```bash
cp -r infrastructure/projects/_template infrastructure/projects/<my_project>
```

### 2. Choose a `project_slug`

The slug is a short, unique abbreviation (e.g. `sales`, `cust`, `legacy`).
It appears in every resource name:

```
{domain_abbr}-{project_slug}-{job_name}-{env}
```

### 3. Fill in the Terraform files

| File | Contents |
|------|----------|
| `variables.tf` | Already defined by the template |
| `tables.tf` | Standard tables in RAW, Iceberg tables in refined/curated |
| `jobs.tf` | One `module "job_*"` per Glue job |
| `optimizers.tf` | One optimizer per Iceberg table |
| `pipelines.tf` | StepFunctions pipeline wiring jobs together |
| `outputs.tf` | Export job names, table ARNs, pipeline ARNs |

### 4. Wire the project into the aggregator

Edit `infrastructure/projects/main.tf` and add a module block:

```hcl
module "my_project" {
  source = "./my_project"

  env           = var.env
  domain_abbr   = var.domain_abbr
  domain_name   = var.domain_name
  project_slug  = "myprj"        # unique short slug
  artifacts_bucket = var.artifacts_bucket
  raw_bucket       = var.raw_bucket
  refined_bucket   = var.refined_bucket
  curated_bucket   = var.curated_bucket
}
```

### 5. Create the job scripts directory

```bash
mkdir -p src/jobs/<my_project>
```

Create job files following the naming convention `job_<name>.py`.
See [adding-a-job.md](adding-a-job.md) for the full guide.

### 6. Validate

```bash
make terraform-plan-dev
make test
```

---

## Checklist

- [ ] Template copied to `infrastructure/projects/<name>/`
- [ ] `project_slug` chosen and added to the module block
- [ ] `tables.tf` defines all required tables
- [ ] `jobs.tf` defines all Glue jobs
- [ ] `optimizers.tf` has one optimizer per Iceberg table
- [ ] `pipelines.tf` wires jobs into a StepFunctions pipeline
- [ ] Module block added to `infrastructure/projects/main.tf`
- [ ] Job scripts created under `src/jobs/<name>/`
- [ ] Unit tests added under `tests/`
- [ ] `terraform plan` runs without errors
