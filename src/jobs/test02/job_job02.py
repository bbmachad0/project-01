"""test02 - job02: Agrega refined e escreve em curated."""

from core.config.settings import get_config
from core.io.writers import write_iceberg
from core.logging.logger import get_logger
from core.spark.session import get_spark


def main() -> None:
    """Job02: Reading data from Iceberg, transformation and writing to S3."""
    spark = get_spark(app_name="t2-job02")
    cfg = get_config()
    log = get_logger(__name__)

    log.info("Starting job02")

    df = spark.read.parquet(f"s3://{cfg['s3_raw_bucket']}/t2/events/")

    # ... transformações ...

    write_iceberg(
        df=df,
        table=f"glue_catalog.{cfg['iceberg_database_refined']}.events",
        mode="append",
    )

    log.info("job02 complete")
    spark.stop()


if __name__ == "__main__":
    main()
