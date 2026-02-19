# ─── Local Spark Development Environment ─────────────────────────
# Mirrors the AWS Glue 5.1 runtime: Python 3.11, Spark 3.5, Iceberg.
# Use this image for `make docker-run` or interactive development.

FROM python:3.11-slim AS base

# ── System dependencies ───────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless \
        curl \
        jq \
        procps \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# ── Spark installation ────────────────────────────────────────────
ENV SPARK_VERSION=3.5.6
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV PATH="${SPARK_HOME}/bin:${PATH}"
ENV PYSPARK_PYTHON=python3

RUN curl -fsSL \
        "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" \
        -o /tmp/spark.tgz \
    && tar -xzf /tmp/spark.tgz -C /opt/ \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} ${SPARK_HOME} \
    && rm /tmp/spark.tgz

# ── Python dependencies ──────────────────────────────────────────
WORKDIR /app

COPY pyproject.toml ./
COPY setup/domain.json ./setup/
# Install in editable-friendly layout (build deps only first)
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir pyspark==${SPARK_VERSION} ".[dev]" \
    || pip install --no-cache-dir pyspark==${SPARK_VERSION} pytest ruff build

# ── Application code ─────────────────────────────────────────────
COPY src/ ./src/
COPY tests/ ./tests/
COPY Makefile ./

# Install the project in editable mode
RUN pip install --no-cache-dir -e .

# ── Environment defaults ─────────────────────────────────────────
ENV ENV=local
ENV PYTHONUNBUFFERED=1
ENV PYSPARK_DRIVER_PYTHON=python3

# ── Entrypoint ───────────────────────────────────────────────────
# Default: drop into a shell. Override with a specific job script.
CMD ["bash"]
