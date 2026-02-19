# core - Shared library for the data domain.
#
# Enterprise package layout:
#   core.spark     - SparkSession factory
#   core.io        - DataFrame readers & writers
#   core.iceberg   - Iceberg DDL helpers & maintenance
#   core.config    - Runtime configuration resolver
#   core.logging   - Structured logging

from core.config.settings import get_config  # noqa: F401
from core.logging.logger import get_logger  # noqa: F401
from core.spark.session import get_spark  # noqa: F401
