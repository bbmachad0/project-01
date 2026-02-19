"""project01 - Job teste..."""

from core.config.settings import get_config
from core.io.writers import write_iceberg
from core.logging.logger import get_logger
from core.spark.session import get_spark


def main() -> None:
    spark = get_spark(app_name="project01-teste")
    cfg = get_config()
    log = get_logger(__name__)

    log.info("Starting teste job")

    # ── Transform ────────────────────────────────
    result = spark.createDataFrame([], schema="id STRING, value STRING, created_at TIMESTAMP")

    # ── Load ─────────────────────────────────────
    write_iceberg(
        df=result,
        path=f"s3://{cfg['s3_curated_bucket']}/iceberg/teste",
        catalog_db=cfg["curated_db"],
        table="teste",
        mode="append",
    )

    log.info("teste job complete")
    spark.stop()


if __name__ == "__main__":
    main()
