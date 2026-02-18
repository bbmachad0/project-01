# ─── Data Mesh Domain Makefile ────────────────────────────────────
# All config read from domain.json — edit that file, not this one.

.DEFAULT_GOAL := help
SHELL := /bin/bash

# Read from domain.json (single source of truth)
DOMAIN_ABBR  := $(shell jq -r .domain_abbr domain.json)
AWS_REGION   := $(shell jq -r .aws_region domain.json)

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
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e AWS_REGION=$(AWS_REGION) \
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

# ─── Upload Artifacts ────────────────────────────────────────────

.PHONY: upload-jobs
upload-jobs: ## Sync job scripts to S3 artifacts bucket
	aws s3 sync src/jobs/ \
		s3://$(DOMAIN_ABBR)-artifacts-$(ENVIRONMENT)/jobs/ \
		--delete --exact-timestamps

.PHONY: upload-wheel
upload-wheel: build ## Build and upload wheel to S3
	WHEEL=$$(ls $(WHEEL_DIR)/*.whl | head -1) && \
	aws s3 cp "$$WHEEL" \
		s3://$(DOMAIN_ABBR)-artifacts-$(ENVIRONMENT)/wheels/$(WHEEL_NAME)
