#!/usr/bin/env bash
# ─── Domain bootstrap - plug-and-play installer ─────────────────
# Idempotent setup for Ubuntu 24.04+ / WSL2.
# Installs ALL dependencies and configures the development environment.
#
# Usage:
#   ./setup/bootstrap.sh            # full install + project setup
#   ./setup/bootstrap.sh --docker   # Docker-based alternative
#
# Pre-requisite: Ubuntu 24.04+ or WSL2 with Ubuntu 24.04+.

set -euo pipefail

# ─── Tool Versions ───────────────────────────────────────────────

PYTHON_VERSION="3.11"
JAVA_VERSION="17"
SCALA_VERSION="2.12.18"
SPARK_VERSION="3.5.6"
HADOOP_VERSION="3"
TERRAFORM_VERSION="1.14.5"

# ─── Project Config ─────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN_JSON="${SCRIPT_DIR}/domain.json"
VENV_DIR=".venv"
ENV_FILE=".env"

# ─── Output helpers ──────────────────────────────────────────────

info()  { printf "\033[1;34m[bootstrap]\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[bootstrap]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[bootstrap]\033[0m %s\n" "$*" >&2; }
fail()  { printf "\033[1;31m[bootstrap]\033[0m %s\n" "$*" >&2; exit 1; }

need_sudo() {
    if ! sudo -n true 2>/dev/null; then
        info "Some steps require sudo. You may be prompted for your password."
    fi
}

# ─── System packages ────────────────────────────────────────────

install_system_packages() {
    info "Installing system packages ..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        curl wget unzip tar gzip jq git \
        build-essential software-properties-common \
        ca-certificates gnupg lsb-release
    ok "System packages installed"
}

# ─── Java 17 ────────────────────────────────────────────────────

install_java() {
    if command -v java &>/dev/null; then
        local jver
        jver=$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')
        if (( jver >= JAVA_VERSION )); then
            ok "Java ${jver} already installed"
            return 0
        fi
    fi
    info "Installing OpenJDK ${JAVA_VERSION} ..."
    sudo apt-get install -y -qq openjdk-${JAVA_VERSION}-jdk-headless
    ok "Java ${JAVA_VERSION} installed"
}

# ─── Python ─────────────────────────────────────────────────────

install_python() {
    if command -v "python${PYTHON_VERSION}" &>/dev/null; then
        ok "Python ${PYTHON_VERSION} already installed"
        return 0
    fi
    info "Installing Python ${PYTHON_VERSION} via deadsnakes PPA ..."
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        "python${PYTHON_VERSION}" \
        "python${PYTHON_VERSION}-venv" \
        "python${PYTHON_VERSION}-dev"
    ok "Python ${PYTHON_VERSION} installed"
    # NOTE: We do NOT override the system python3 symlink.
    # Ubuntu system tools (apt_pkg, etc.) depend on the default
    # Python version. We use python3.11 explicitly everywhere.
}

# ─── Scala ───────────────────────────────────────────────────────

install_scala() {
    if command -v scala &>/dev/null; then
        local sver
        sver=$(scala -version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
        if [[ "${sver}" == "${SCALA_VERSION}" ]]; then
            ok "Scala ${SCALA_VERSION} already installed"
            return 0
        fi
    fi
    info "Installing Scala ${SCALA_VERSION} ..."
    local tmp="/tmp/scala-${SCALA_VERSION}.tgz"
    curl -fsSL "https://downloads.lightbend.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz" -o "${tmp}"
    sudo tar xzf "${tmp}" -C /usr/local/share/
    sudo ln -sf "/usr/local/share/scala-${SCALA_VERSION}/bin/scala" /usr/local/bin/scala
    sudo ln -sf "/usr/local/share/scala-${SCALA_VERSION}/bin/scalac" /usr/local/bin/scalac
    rm -f "${tmp}"
    ok "Scala ${SCALA_VERSION} installed"
}

# ─── Spark ───────────────────────────────────────────────────────

install_spark() {
    local spark_dir="/opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}"
    if [[ -d "${spark_dir}" ]]; then
        ok "Spark ${SPARK_VERSION} already installed"
    else
        info "Installing Spark ${SPARK_VERSION} ..."
        local tmp="/tmp/spark-${SPARK_VERSION}.tgz"
        curl -fsSL \
            "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" \
            -o "${tmp}"
        sudo tar xzf "${tmp}" -C /opt/
        rm -f "${tmp}"
        ok "Spark ${SPARK_VERSION} installed"
    fi
    sudo ln -sfn "${spark_dir}" /opt/spark
}

# ─── AWS CLI v2 ──────────────────────────────────────────────────

install_aws_cli() {
    if command -v aws &>/dev/null; then
        ok "AWS CLI $(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2) already installed"
        return 0
    fi
    info "Installing AWS CLI v2 ..."
    local tmp="/tmp/awscli"
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${tmp}.zip"
    unzip -q "${tmp}.zip" -d "${tmp}"
    sudo "${tmp}/aws/install" --update
    rm -rf "${tmp}" "${tmp}.zip"
    ok "AWS CLI v2 installed"
}

# ─── Terraform ───────────────────────────────────────────────────

install_terraform() {
    if command -v terraform &>/dev/null; then
        local tfver
        tfver=$(terraform version -json 2>/dev/null \
            | "python${PYTHON_VERSION}" -c "import sys,json;print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null \
            || terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        ok "Terraform ${tfver} already installed"
        return 0
    fi
    info "Installing Terraform ..."
    wget -qO- https://apt.releases.hashicorp.com/gpg \
        | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq terraform
    ok "Terraform $(terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') installed"
}

# ─── UV (with UVX) ──────────────────────────────────────────────

install_uv() {
    if command -v uv &>/dev/null; then
        ok "UV $(uv --version 2>&1 | awk '{print $2}') already installed"
        return 0
    fi
    info "Installing UV ..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="${HOME}/.local/bin:${PATH}"
    ok "UV $(uv --version 2>&1 | awk '{print $2}') installed"
}

# ─── Environment variables (persistent) ─────────────────────────

setup_env_vars() {
    local profile_script="/etc/profile.d/data-domain-tools.sh"
    if [[ -f "${profile_script}" ]]; then
        ok "Environment variables already configured"
    else
        info "Configuring environment variables ..."
        sudo tee "${profile_script}" > /dev/null <<ENVEOF
export JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64
export SPARK_HOME=/opt/spark
export SCALA_HOME=/usr/local/share/scala-${SCALA_VERSION}
export PYSPARK_PYTHON=python${PYTHON_VERSION}
export PATH="\${SPARK_HOME}/bin:\${SCALA_HOME}/bin:\${PATH}"
ENVEOF
        ok "Environment variables written to ${profile_script}"
    fi

    # Source for current session
    export JAVA_HOME="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64"
    export SPARK_HOME="/opt/spark"
    export SCALA_HOME="/usr/local/share/scala-${SCALA_VERSION}"
    export PYSPARK_PYTHON="python${PYTHON_VERSION}"
    export PATH="${SPARK_HOME}/bin:${SCALA_HOME}/bin:${HOME}/.local/bin:${PATH}"
}

# ─── Project setup ───────────────────────────────────────────────

setup_venv() {
    info "Setting up Python virtual environment ..."
    if [[ -d "${VENV_DIR}" && ! -f "${VENV_DIR}/bin/activate" ]]; then
        warn "Broken ${VENV_DIR} detected - recreating"
        rm -rf "${VENV_DIR}"
    fi
    if [[ ! -d "${VENV_DIR}" ]]; then
        uv venv --python "python${PYTHON_VERSION}" "${VENV_DIR}" 2>/dev/null \
            || "python${PYTHON_VERSION}" -m venv "${VENV_DIR}"
        ok "Created ${VENV_DIR} (Python ${PYTHON_VERSION})"
    else
        ok "${VENV_DIR} already exists"
    fi

    # shellcheck disable=SC1091
    source "${VENV_DIR}/bin/activate"
}

install_dependencies() {
    info "Installing project in editable mode with dev extras ..."
    uv pip install -e ".[dev]" 2>/dev/null \
        || pip install --quiet -e ".[dev]"
    ok "Dependencies installed"
}

setup_env_file() {
    if [[ ! -f "${DOMAIN_JSON}" ]]; then
        fail "domain.json not found at ${DOMAIN_JSON}"
    fi

    local domain_abbr domain_name aws_region account_id
    domain_abbr=$(jq -r .domain_abbr "${DOMAIN_JSON}")
    domain_name=$(jq -r .domain_name "${DOMAIN_JSON}")
    aws_region=$(jq -r .aws_region "${DOMAIN_JSON}")

    # Resolve account ID for bucket naming (best-effort)
    account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || true

    if [[ -f "${ENV_FILE}" ]]; then
        ok "${ENV_FILE} already exists - skipping"
        return 0
    fi

    if [[ -n "${account_id}" ]]; then
        cat > "${ENV_FILE}" <<EOF
# Generated by setup/bootstrap.sh
# Source: setup/domain.json (${domain_name})
# Bucket naming: {domain_abbr}-{purpose}-{account_id}-{env}
ENV=local
AWS_REGION=${aws_region}
AWS_ACCOUNT_ID=${account_id}
LOG_LEVEL=INFO
LOG_FORMAT=text

# Bucket overrides (uncomment to customise)
# ${domain_abbr^^}_S3_RAW_BUCKET=${domain_abbr}-raw-${account_id}-local
# ${domain_abbr^^}_S3_REFINED_BUCKET=${domain_abbr}-refined-${account_id}-local
# ${domain_abbr^^}_S3_CURATED_BUCKET=${domain_abbr}-curated-${account_id}-local
# ${domain_abbr^^}_S3_ARTIFACTS_BUCKET=${domain_abbr}-artifacts-${account_id}-local
EOF
    else
        warn "AWS credentials not found - bucket names will use local-only defaults."
        cat > "${ENV_FILE}" <<EOF
# Generated by setup/bootstrap.sh
# Source: setup/domain.json (${domain_name})
# NOTE: AWS_ACCOUNT_ID not resolved - set it manually for S3 access.
# Bucket naming: {domain_abbr}-{purpose}-{account_id}-{env}
ENV=local
AWS_REGION=${aws_region}
# AWS_ACCOUNT_ID=<your-account-id>
LOG_LEVEL=INFO
LOG_FORMAT=text

# Bucket overrides (uncomment and set account ID)
# ${domain_abbr^^}_S3_RAW_BUCKET=${domain_abbr}-raw-<account_id>-local
# ${domain_abbr^^}_S3_REFINED_BUCKET=${domain_abbr}-refined-<account_id>-local
# ${domain_abbr^^}_S3_CURATED_BUCKET=${domain_abbr}-curated-<account_id>-local
# ${domain_abbr^^}_S3_ARTIFACTS_BUCKET=${domain_abbr}-artifacts-<account_id>-local
EOF
    fi
    ok "Generated ${ENV_FILE} from domain.json"
}

# ─── Docker path ─────────────────────────────────────────────────

run_docker_bootstrap() {
    if ! command -v docker &>/dev/null; then
        fail "Docker is required for --docker mode but not found."
    fi
    docker info &>/dev/null || fail "Docker daemon is not running."

    local domain_abbr
    domain_abbr=$(jq -r .domain_abbr "${DOMAIN_JSON}")

    setup_env_file

    info "Building Docker image ..."
    docker build -t "${domain_abbr}-local:latest" .
    ok "Docker image built"

    info "Verifying image ..."
    docker run --rm "${domain_abbr}-local:latest" python3 -c "import core; print('core importable')"
    ok "Docker environment ready"
    ok "Run jobs with:  make docker-run JOB=sales/job_daily_sales.py"
}

# ─── Verification ────────────────────────────────────────────────

verify_installation() {
    info "Verifying installation ..."
    python3 -c "from core.spark.session import get_spark; print('spark_session OK')"
    python3 -c "from core.config.settings import get_config; print('config OK')"
    python3 -c "from core.logging.logger import get_logger; print('logging OK')"
    ok "Core library imports verified"
}

run_quick_checks() {
    info "Running linter ..."
    if ruff check src/ tests/ --quiet 2>/dev/null; then
        ok "Lint passed"
    else
        warn "Lint issues found - run 'make lint' for details"
    fi
}

# ─── Summary ─────────────────────────────────────────────────────

print_summary() {
    echo ""
    echo "────────────────────────────────────────────────────"
    ok "Bootstrap complete"
    echo ""
    info "Installed tools:"
    echo "    Java          $(java -version 2>&1 | head -1 | sed -E 's/.*"(.*)".*/\1/')"
    echo "    Python        $(python${PYTHON_VERSION} --version 2>&1 | awk '{print $2}')"
    echo "    Scala         ${SCALA_VERSION}"
    echo "    Spark         ${SPARK_VERSION}"
    echo "    Terraform     $(terraform version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo 'N/A')"
    echo "    AWS CLI       $(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2 || echo 'N/A')"
    echo "    UV            $(uv --version 2>&1 | awk '{print $2}' || echo 'N/A')"
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

    local domain_name="unknown"
    local domain_abbr="xx"
    if command -v jq &>/dev/null && [[ -f "${DOMAIN_JSON}" ]]; then
        domain_name=$(jq -r .domain_name "${DOMAIN_JSON}")
        domain_abbr=$(jq -r .domain_abbr "${DOMAIN_JSON}")
    fi

    info "Bootstrapping ${domain_name} (${domain_abbr}) ..."
    echo ""

    if [[ "${1:-}" == "--docker" ]]; then
        run_docker_bootstrap
        return 0
    fi

    need_sudo

    # ── Install system dependencies ──────────────────────────────
    install_system_packages
    install_java
    install_python
    install_scala
    install_spark
    install_aws_cli
    install_terraform
    install_uv
    setup_env_vars
    echo ""

    # ── Project setup ────────────────────────────────────────────
    setup_venv
    install_dependencies
    setup_env_file
    echo ""

    # ── Verify ───────────────────────────────────────────────────
    verify_installation
    run_quick_checks
    print_summary
}

main "$@"
