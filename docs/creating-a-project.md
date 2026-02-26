# Creating a Project

A **project** is an isolated unit of work within the domain - it owns its
tables, Glue jobs, optimizers, and pipelines. Each project lives in two places:

- **Infrastructure** → `infrastructure/projects/<name>/`
- **Job scripts** → `src/jobs/<name>/`

---

## Step-by-step

### 1. Use the make command (recommended)

```bash
make new-project NAME=<my_project> 
```

This copies `_template/`, sets `project.json`, and prints next steps.

**Or manually:**

```bash
cp -r infrastructure/projects/_template infrastructure/projects/<my_project>
```

### 2. Choose a `project_name`

The name is a short, unique abbreviation (e.g. `sales`, `cust`, `legacy`).
It appears in every resource name:

```
{domain_abbr}-{project_name}-{job_name}-{env}
```

### 3. Fill in the Terraform files

| File | Contents |
|------|----------|
| `project.json` | Set `name` - the only required config |
| `tables.tf` | Standard tables in RAW, Iceberg tables in refined/curated |
| `jobs.tf` | One `module "job_*"` per Glue job |
| `optimizers.tf` | One optimizer per Iceberg table |
| `pipelines.tf` | StepFunctions pipeline wiring jobs together |
| `outputs.tf` | Export job names, table ARNs, pipeline ARNs |

> Use `local.baseline.*` to access shared resources (buckets, databases, etc.).
> See `_template/README.md` for the full list of available locals.

### 4. Commit and push

```bash
git add infrastructure/projects/<my_project>/
git commit -m "feat: add <my_project> project"
git push origin dev
```

CI/CD auto-discovers the new directory. **No changes to any central file needed.**

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

## Removing a Project

Projects are decommissioned through the same CI/CD pipeline that creates them  -
no manual `terraform destroy` required.

### Steps

```bash
# 1. Delete both directories
rm -rf infrastructure/projects/<my_project>
rm -rf src/jobs/<my_project>

# 2. Commit and push
git add -A
git commit -m "chore: remove <my_project>"
git push origin dev
```

The deploy workflow automatically detects the removed `project.json` and:

1. Restores the Terraform files from the previous commit.
2. Runs `terraform destroy` to remove all AWS resources (Glue jobs, IAM roles,
   tables, optimizers, Step Functions pipelines).
3. Removes the project's job scripts from S3 (via `s3 sync --delete`).

> **Note:** Underlying data in S3 data buckets (raw/refined/curated) is **not**
> deleted. Clean up data prefixes manually if needed.

See [ci-cd.md- Removing a Project](ci-cd.md#removing-a-project) for full
details and caveats.

---

## Checklist

- [ ] Template copied to `infrastructure/projects/<name>/`
- [ ] `project_name` chosen and added to the module block
- [ ] `tables.tf` defines all required tables
- [ ] `jobs.tf` defines all Glue jobs
- [ ] `optimizers.tf` has one optimizer per Iceberg table
- [ ] `pipelines.tf` wires jobs into a StepFunctions pipeline
- [ ] Module block added to `infrastructure/projects/main.tf`
- [ ] Job scripts created under `src/jobs/<name>/`
- [ ] Unit tests added under `tests/`
- [ ] `terraform plan` runs without errors
