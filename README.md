# Data Domain - Enterprise AWS Data Mesh Repository

Production-ready mono-repository for an AWS Data Mesh domain built on
**AWS Glue 5.1**, **Apache Iceberg**, **Terraform**, and **GitHub Actions**.

---

## Getting Started

See **[setup/README.md](setup/README.md)** for the full step-by-step guide.

Quick start:

```bash
# Review setup/domain.json, then:
./setup/bootstrap.sh            # local venv
./setup/init-terraform.sh       # generate Terraform backend configs
```

---

## Repository Structure

```
.
├── setup/
│   ├── domain.json              # Single source of truth (names, region)
│   ├── bootstrap.sh             # One-time setup script
│   └── init-terraform.sh        # Generate Terraform backend configs
├── src/
│   ├── core/                    # Shared Python library (packaged as .whl)
│   └── jobs/                    # Glue job scripts (NOT in the wheel)
│       ├── sales/
│       ├── customers/
│       └── legacy_refactor/
├── tests/
├── infrastructure/
│   ├── modules/                 # Reusable Terraform modules
│   ├── foundation/              # Shared infra (S3, IAM, Glue databases)
│   ├── projects/                # Per-project stacks (tables, jobs, pipelines)
│   └── environments/            # Per-env root modules (dev, int, prod)
├── .github/workflows/           # CI/CD (ci, deploy-dev, deploy-int, deploy-prod)
├── setup/                       # One-time setup scripts & guide
├── docs/                        # Detailed documentation
├── Dockerfile
├── Makefile
└── pyproject.toml
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [setup/README.md](setup/README.md) | Prerequisites, bootstrap, first-time setup |
| [docs/architecture.md](docs/architecture.md) | Domain hierarchy, layers, naming conventions |
| [docs/creating-a-project.md](docs/creating-a-project.md) | How to add a new project to the domain |
| [docs/adding-a-job.md](docs/adding-a-job.md) | How to add a new Glue job |
| [docs/ci-cd.md](docs/ci-cd.md) | Branch strategy, workflows, OIDC setup |
| [docs/terraform.md](docs/terraform.md) | Module hierarchy, foundation vs projects |

---

## License

Proprietary. See [LICENSE](LICENSE) for details.