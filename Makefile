# ─── Data Mesh Domain Makefile ────────────────────────────────────
# All config read from setup/domain.json - edit that file, not this one.

.DEFAULT_GOAL := help
SHELL := /bin/bash

# Read from setup/domain.json (single source of truth)
DOMAIN_ABBR  := $(shell jq -r .domain_abbr setup/domain.json)
AWS_REGION   := $(shell jq -r .aws_region setup/domain.json)
ACCOUNT_ID   := $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)

PYTHON       := python3
PIP          := pip
PYTEST       := pytest
DOCKER       := docker
TF           := terraform
ENVIRONMENT  ?= dev

DOCKER_IMAGE := $(DOMAIN_ABBR)-local
DOCKER_TAG   := latest
WHEEL_DIR    := dist
WHEEL_NAME   := core-latest-py3-none-any.whl

# ─── Help ────────────────────────────────────────────────────────

.PHONY: help
help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

# ─── Bootstrap ───────────────────────────────────────────────────

.PHONY: bootstrap
bootstrap: ## Run full local environment setup (idempotent)
	@./setup/bootstrap.sh

.PHONY: bootstrap-docker
bootstrap-docker: ## Bootstrap using Docker instead of a local venv
	@./setup/bootstrap.sh --docker

# ─── Local Development ───────────────────────────────────────────

.PHONY: install
install: ## Install project in editable mode with dev dependencies
	$(PIP) install -e ".[dev]"

.PHONY: run-local
run-local: ## Run a job locally (usage: make run-local JOB=sales/job_daily_sales.py)
	ENV=local $(PYTHON) src/jobs/$(JOB)

.PHONY: docker-build
docker-build: ## Build the local Spark development Docker image
	$(DOCKER) build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

.PHONY: docker-run
docker-run: ## Run a job inside the local Docker container
	$(DOCKER) run --rm \
		-e ENV=local \
		-e AWS_REGION=$(AWS_REGION) \
		-v $(HOME)/.aws:/root/.aws:ro \
		-v $(PWD)/src:/app/src \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		$(PYTHON) src/jobs/$(JOB)

# ─── Testing ─────────────────────────────────────────────────────

.PHONY: test
test: ## Run all unit tests with coverage
	$(PYTEST) tests/ -v --tb=short --cov=core --cov-report=term-missing

.PHONY: lint
lint: ## Run linters (ruff)
	ruff check src/ tests/
	ruff format --check src/ tests/

.PHONY: format
format: ## Auto-format code with ruff
	ruff format src/ tests/
	ruff check --fix src/ tests/

.PHONY: typecheck
typecheck: ## Run mypy type checking
	mypy src/core/

# ─── Build ───────────────────────────────────────────────────────

.PHONY: build
build: ## Build the .whl distribution
	rm -rf $(WHEEL_DIR)
	$(PYTHON) -m build --wheel --outdir $(WHEEL_DIR)

.PHONY: clean
clean: ## Remove build artifacts and caches
	rm -rf $(WHEEL_DIR) build *.egg-info src/*.egg-info
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

# ─── Terraform ───────────────────────────────────────────────────

.PHONY: terraform-init
terraform-init: ## Initialize Terraform for an environment (ENVIRONMENT=dev|int|prod)
	cd infrastructure/environments/$(ENVIRONMENT) && $(TF) init -backend-config=backend.conf

.PHONY: terraform-init-dev
terraform-init-dev: ## Initialize Terraform for Dev
	cd infrastructure/environments/dev && $(TF) init -backend-config=backend.conf

.PHONY: terraform-init-int
terraform-init-int: ## Initialize Terraform for Int
	cd infrastructure/environments/int && $(TF) init -backend-config=backend.conf

.PHONY: terraform-init-prod
terraform-init-prod: ## Initialize Terraform for Prod
	cd infrastructure/environments/prod && $(TF) init -backend-config=backend.conf

.PHONY: terraform-plan-dev
terraform-plan-dev: ## Run Terraform plan for Dev
	cd infrastructure/environments/dev && $(TF) init -backend-config=backend.conf && $(TF) plan

.PHONY: terraform-plan-int
terraform-plan-int: ## Run Terraform plan for Int
	cd infrastructure/environments/int && $(TF) init -backend-config=backend.conf && $(TF) plan

.PHONY: terraform-plan-prod
terraform-plan-prod: ## Run Terraform plan for Prod
	cd infrastructure/environments/prod && $(TF) init -backend-config=backend.conf && $(TF) plan

.PHONY: terraform-apply
terraform-apply: ## Apply Terraform for an environment (ENVIRONMENT=dev|int|prod)
	cd infrastructure/environments/$(ENVIRONMENT) && $(TF) apply

.PHONY: terraform-validate
terraform-validate: ## Validate Terraform for all environments
	@for env in dev int prod; do \
		echo "──── Validating $$env ────"; \
		cd infrastructure/environments/$$env && $(TF) init -backend=false && $(TF) validate && cd ../../..; \
	done

.PHONY: init-terraform
init-terraform: ## Regenerate all backend.conf files from domain.json
	@./setup/init-terraform.sh

.PHONY: new-project
new-project: ## Scaffold a new project  (NAME=<dir_name>  SLUG=<short_id>)
	@[ -n "$(NAME)" ] || { echo "Usage: make new-project NAME=<name> SLUG=<slug>"; exit 1; }
	@[ -n "$(SLUG)" ] || { echo "Usage: make new-project NAME=<name> SLUG=<slug>"; exit 1; }
	@[ ! -d "infrastructure/projects/$(NAME)" ] || \
		{ echo "ERROR: infrastructure/projects/$(NAME) already exists"; exit 1; }
	cp -r infrastructure/projects/_template infrastructure/projects/$(NAME)
	printf '{\n  "slug": "$(SLUG)"\n}\n' > infrastructure/projects/$(NAME)/project.json
	@echo ""
	@echo "Created infrastructure/projects/$(NAME)/"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit tables.tf    - define Glue Data Catalog tables"
	@echo "  2. Edit jobs.tf      - define Glue Jobs"
	@echo "  3. Edit optimizers.tf - wire table optimizers"
	@echo "  4. Edit pipelines.tf  - compose Step Function pipelines"
	@echo "  5. Commit and push   - CI/CD picks the new project up automatically"

.PHONY: tf-init-project
tf-init-project: ## Init Terraform for a single project  (PROJECT=<name> ENVIRONMENT=dev|int|prod)
	@[ -n "$(PROJECT)" ] || { echo "Usage: make tf-init-project PROJECT=<name> ENVIRONMENT=dev|int|prod"; exit 1; }
	$(eval SLUG := $(shell jq -r .slug infrastructure/projects/$(PROJECT)/project.json))
	cd infrastructure/projects/$(PROJECT) && \
	  $(TF) init \
	    -backend-config="bucket=tfstate-$(ACCOUNT_ID)" \
	    -backend-config="key=projects/$(SLUG)/terraform.tfstate" \
	    -backend-config="region=$(AWS_REGION)" \
	    -backend-config="use_lockfile=true"

.PHONY: tf-plan-project
tf-plan-project: tf-init-project ## Plan Terraform for a single project  (PROJECT=<name> ENVIRONMENT=dev|int|prod)
	cd infrastructure/projects/$(PROJECT) && \
	  $(TF) plan -var="environment=$(ENVIRONMENT)"

.PHONY: tf-apply-project
tf-apply-project: tf-init-project ## Apply Terraform for a single project  (PROJECT=<name> ENVIRONMENT=dev|int|prod)
	cd infrastructure/projects/$(PROJECT) && \
	  $(TF) apply -var="environment=$(ENVIRONMENT)"

# ─── Upload Artifacts ────────────────────────────────────────────

.PHONY: upload-jobs
upload-jobs: ## Sync job scripts to S3 artifacts bucket
	aws s3 sync src/jobs/ \
		s3://$(DOMAIN_ABBR)-artifacts-$(ACCOUNT_ID)-$(ENVIRONMENT)/jobs/ \
		--delete --exact-timestamps

.PHONY: upload-wheel
upload-wheel: build ## Build and upload wheel to S3
	WHEEL=$$(ls $(WHEEL_DIR)/*.whl | head -1) && \
	aws s3 cp "$$WHEEL" \
		s3://$(DOMAIN_ABBR)-artifacts-$(ACCOUNT_ID)-$(ENVIRONMENT)/wheels/$(WHEEL_NAME)
