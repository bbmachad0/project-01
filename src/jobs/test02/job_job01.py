"""test02 - job01: Ingest raw events e escreve em refined."""

from core.config.settings import get_config
from core.io.readers import read_iceberg
from core.io.writers import write_iceberg
from core.logging.logger import get_logger
from core.spark.session import get_spark


def main() -> None:
    """Job01: Leitura de dados do S3, transformação e escrita no Iceberg."""
    spark = get_spark(app_name="t2-job01")
    cfg = get_config()
    log = get_logger(__name__)

    log.info("Starting job01")

    df = read_iceberg(
        spark=spark,
        table=f"glue_catalog.{cfg['iceberg_database_raw']}.events",
    )

    write_iceberg(
        df=df,
        table=f"glue_catalog.{cfg['iceberg_database_refined']}.events",
        mode="append",
    )

    log.info("job01 complete")
    spark.stop()


if __name__ == "__main__":
    main()
