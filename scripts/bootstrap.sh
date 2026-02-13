#!/usr/bin/env bash
# ─── domain-project bootstrap ────────────────────────────────────
# Idempotent local development environment setup.
# Usage:
#   ./scripts/bootstrap.sh            # standard setup
#   ./scripts/bootstrap.sh --docker   # use Docker instead of local venv

set -euo pipefail

# ─── Constants ───────────────────────────────────────────────────

REQUIRED_PYTHON_MINOR=11
REQUIRED_JAVA_MAJOR=17
VENV_DIR=".venv"
ENV_EXAMPLE=".env.example"
ENV_FILE=".env"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── Output helpers ──────────────────────────────────────────────

info()  { printf "\033[1;34m[bootstrap]\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[bootstrap]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[bootstrap]\033[0m %s\n" "$*" >&2; }
fail()  { printf "\033[1;31m[bootstrap]\033[0m %s\n" "$*" >&2; exit 1; }

# ─── Dependency checks ──────────────────────────────────────────

check_command() {
    command -v "$1" &>/dev/null || fail "'$1' is required but not found in PATH."
}

check_python() {
    info "Checking Python …"
    check_command python3
    local ver
    ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local minor
    minor=$(python3 -c "import sys; print(sys.version_info.minor)")
    if (( minor < REQUIRED_PYTHON_MINOR )); then
        fail "Python >= 3.${REQUIRED_PYTHON_MINOR} required (found ${ver})."
    fi
    ok "Python ${ver}"
}

check_java() {
    info "Checking Java …"
    check_command java
    local jver
    jver=$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')
    if (( jver < REQUIRED_JAVA_MAJOR )); then
        fail "Java >= ${REQUIRED_JAVA_MAJOR} required (found major ${jver})."
    fi
    ok "Java ${jver}"
}

check_docker() {
    info "Checking Docker …"
    check_command docker
    docker info &>/dev/null || fail "Docker daemon is not running."
    ok "Docker available"
}

check_terraform() {
    if command -v terraform &>/dev/null; then
        local tfver
        tfver=$(terraform version -json 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null || terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        ok "Terraform ${tfver}"
    else
        warn "Terraform not found — infrastructure commands will not work."
    fi
}

check_aws_cli() {
    if command -v aws &>/dev/null; then
        ok "AWS CLI $(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)"
    else
        warn "AWS CLI not found — S3 uploads and cloud operations will not work."
    fi
}

# ─── Virtual environment ─────────────────────────────────────────

setup_venv() {
    info "Setting up Python virtual environment …"
    if [[ -d "${VENV_DIR}" && ! -f "${VENV_DIR}/bin/activate" ]]; then
        warn "Broken ${VENV_DIR} detected — recreating"
        rm -rf "${VENV_DIR}"
    fi
    if [[ ! -d "${VENV_DIR}" ]]; then
        python3 -m venv "${VENV_DIR}"
        ok "Created ${VENV_DIR}"
    else
        ok "${VENV_DIR} already exists"
    fi

    # shellcheck disable=SC1091
    source "${VENV_DIR}/bin/activate"

    info "Upgrading pip …"
    pip install --quiet --upgrade pip setuptools wheel
}

install_dependencies() {
    info "Installing project in editable mode with dev extras …"
    pip install --quiet -e ".[dev]"
    ok "Dependencies installed"
}

# ─── Environment file ────────────────────────────────────────────

setup_env_file() {
    if [[ -f "${ENV_EXAMPLE}" ]]; then
        if [[ ! -f "${ENV_FILE}" ]]; then
            cp "${ENV_EXAMPLE}" "${ENV_FILE}"
            ok "Created ${ENV_FILE} from ${ENV_EXAMPLE}"
        else
            ok "${ENV_FILE} already exists — skipping"
        fi
    fi
}

# ─── Docker path ─────────────────────────────────────────────────

run_docker_bootstrap() {
    check_docker
    setup_env_file

    info "Building Docker image …"
    docker build -t domain-project-local:latest .
    ok "Docker image built"

    info "Verifying image …"
    docker run --rm domain-project-local:latest python3 -c "import domain_project.core; print('core importable')"
    ok "Docker environment ready"
    ok "Run jobs with:  make docker-run JOB=sales/job_daily_sales.py"
}

# ─── Verification ────────────────────────────────────────────────

verify_installation() {
    info "Verifying installation …"
    python3 -c "from domain_project.core.spark_session import get_spark; print('spark_session OK')"
    python3 -c "from domain_project.core.config import get_config; print('config OK')"
    python3 -c "from domain_project.core.logging import get_logger; print('logging OK')"
    ok "Core library imports verified"
}

run_quick_checks() {
    info "Running linter …"
    if ruff check src/ tests/ --quiet 2>/dev/null; then
        ok "Lint passed"
    else
        warn "Lint issues found — run 'make lint' for details"
    fi
}

# ─── Summary ─────────────────────────────────────────────────────

print_summary() {
    echo ""
    echo "────────────────────────────────────────────────────"
    ok "Bootstrap complete"
    echo ""
    info "Activate the virtualenv:"
    echo "    source ${VENV_DIR}/bin/activate"
    echo ""
    info "Common commands:"
    echo "    make test              Run unit tests"
    echo "    make lint              Run linters"
    echo "    make build             Build .whl"
    echo "    make run-local JOB=sales/job_daily_sales.py"
    echo "    make terraform-plan-dev"
    echo "────────────────────────────────────────────────────"
}

# ─── Main ────────────────────────────────────────────────────────

main() {
    cd "${PROJECT_ROOT}"

    info "Bootstrapping domain-project …"
    echo ""

    if [[ "${1:-}" == "--docker" ]]; then
        run_docker_bootstrap
        return 0
    fi

    check_python
    check_java
    check_terraform
    check_aws_cli
    echo ""

    setup_venv
    install_dependencies
    setup_env_file
    echo ""

    verify_installation
    run_quick_checks
    print_summary
}

main "$@"
