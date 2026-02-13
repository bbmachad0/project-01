# ─── domain-project Makefile ─────────────────────────────────────
# Common development commands for local development, testing,
# building, and infrastructure management.

.DEFAULT_GOAL := help
SHELL := /bin/bash

PROJECT      := domain-project
PYTHON       := python3
PIP          := pip
PYTEST       := pytest
DOCKER       := docker
TF           := terraform
ENVIRONMENT  ?= dev

DOCKER_IMAGE := $(PROJECT)-local
DOCKER_TAG   := latest
WHEEL_DIR    := dist

# ─── Help ────────────────────────────────────────────────────────

.PHONY: help
help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

# ─── Bootstrap ───────────────────────────────────────────────────

.PHONY: bootstrap
bootstrap: ## Run full local environment setup (idempotent)
	@./scripts/bootstrap.sh

.PHONY: bootstrap-docker
bootstrap-docker: ## Bootstrap using Docker instead of a local venv
	@./scripts/bootstrap.sh --docker

# ─── Local Development ───────────────────────────────────────────

.PHONY: install
install: ## Install project in editable mode with dev dependencies
	$(PIP) install -e ".[dev]"

.PHONY: run-local
run-local: ## Run a job locally (usage: make run-local JOB=sales/job_daily_sales.py)
	ENV=local $(PYTHON) src/domain_project/jobs/$(JOB)

.PHONY: docker-build
docker-build: ## Build the local Spark development Docker image
	$(DOCKER) build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

.PHONY: docker-run
docker-run: ## Run a job inside the local Docker container
	$(DOCKER) run --rm \
		-e ENV=local \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e AWS_REGION=eu-west-1 \
		-v $(PWD)/src:/app/src \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		$(PYTHON) src/domain_project/jobs/$(JOB)

# ─── Testing ─────────────────────────────────────────────────────

.PHONY: test
test: ## Run all unit tests with coverage
	$(PYTEST) tests/ -v --tb=short --cov=domain_project --cov-report=term-missing

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
	mypy src/domain_project/core/

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
	cd infrastructure/environments/$(ENVIRONMENT) && $(TF) init

.PHONY: terraform-plan-dev
terraform-plan-dev: ## Run Terraform plan for Dev
	cd infrastructure/environments/dev && $(TF) init && $(TF) plan

.PHONY: terraform-plan-int
terraform-plan-int: ## Run Terraform plan for Int
	cd infrastructure/environments/int && $(TF) init && $(TF) plan

.PHONY: terraform-plan-prod
terraform-plan-prod: ## Run Terraform plan for Prod
	cd infrastructure/environments/prod && $(TF) init && $(TF) plan

.PHONY: terraform-apply
terraform-apply: ## Apply Terraform for an environment (ENVIRONMENT=dev|int|prod)
	cd infrastructure/environments/$(ENVIRONMENT) && $(TF) apply

.PHONY: terraform-validate
terraform-validate: ## Validate Terraform for all environments
	@for env in dev int prod; do \
		echo "──── Validating $$env ────"; \
		cd infrastructure/environments/$$env && $(TF) init -backend=false && $(TF) validate && cd ../../..; \
	done

# ─── Upload Artifacts ────────────────────────────────────────────

.PHONY: upload-jobs
upload-jobs: ## Sync job scripts to S3 artifacts bucket
	aws s3 sync src/domain_project/jobs/ \
		s3://$(PROJECT)-artifacts-$(ENVIRONMENT)/jobs/ \
		--delete --exact-timestamps

.PHONY: upload-wheel
upload-wheel: build ## Build and upload wheel to S3
	WHEEL=$$(ls $(WHEEL_DIR)/*.whl | head -1) && \
	aws s3 cp "$$WHEEL" \
		s3://$(PROJECT)-artifacts-$(ENVIRONMENT)/wheels/domain_project-latest-py3-none-any.whl
