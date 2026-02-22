# Creating a Project

A **project** is an isolated unit of work within the domain - it owns its
tables, Glue jobs, optimizers, and pipelines. Each project lives in two places:

- **Infrastructure** → `infrastructure/projects/<name>/`
- **Job scripts** → `src/jobs/<name>/`

---

## Step-by-step

### 1. Use the make command (recommended)

```bash
make new-project NAME=<my_project> SLUG=<short_id>
```

This copies `_template/`, sets `project.json`, and prints next steps.

**Or manually:**

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
| `project.json` | Set `slug` — the only required config |
| `tables.tf` | Standard tables in RAW, Iceberg tables in refined/curated |
| `jobs.tf` | One `module "job_*"` per Glue job |
| `optimizers.tf` | One optimizer per Iceberg table |
| `pipelines.tf` | StepFunctions pipeline wiring jobs together |
| `outputs.tf` | Export job names, table ARNs, pipeline ARNs |

> Use `local.foundation.*` to access shared resources (buckets, databases, etc.).
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
