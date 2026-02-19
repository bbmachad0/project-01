"""Unit tests for core.config module."""

import json

from core.config.settings import _ABBR, _ENV_PREFIX, get_config


class TestGetConfig:
    """Tests for the get_config() resolver."""

    def test_returns_defaults_when_no_overrides(self, monkeypatch):
        monkeypatch.delenv("ENV", raising=False)
        monkeypatch.delenv("CONFIG_PATH", raising=False)
        monkeypatch.delenv("AWS_ACCOUNT_ID", raising=False)
        for key in ("S3_RAW_BUCKET", "S3_CURATED_BUCKET", "S3_WAREHOUSE_BUCKET"):
            monkeypatch.delenv(f"{_ENV_PREFIX}{key}", raising=False)

        cfg = get_config()

        assert cfg["env"] == "local"
        # Bucket defaults include account_id if available, or just {abbr}-{purpose}-local
        assert cfg["s3_raw_bucket"].startswith(f"{_ABBR}-raw-")
        assert cfg["iceberg_warehouse"].startswith("s3://")

    def test_env_variable_overrides_default(self, monkeypatch):
        monkeypatch.setenv("ENV", "prod")
        cfg = get_config()
        assert cfg["env"] == "prod"

    def test_explicit_overrides_take_precedence(self, monkeypatch):
        monkeypatch.setenv("ENV", "dev")
        cfg = get_config(env="staging")
        assert cfg["env"] == "staging"

    def test_prefixed_env_vars(self, monkeypatch):
        monkeypatch.setenv(f"{_ENV_PREFIX}S3_RAW_BUCKET", "my-custom-bucket")
        cfg = get_config()
        assert cfg["s3_raw_bucket"] == "my-custom-bucket"

    def test_config_file_json(self, monkeypatch, tmp_path):
        config_data = {"s3_raw_bucket": "from-file", "iceberg_database_raw": "raw_v2"}
        config_file = tmp_path / "config.json"
        config_file.write_text(json.dumps(config_data))

        cfg = get_config(config_path=str(config_file))
        assert cfg["s3_raw_bucket"] == "from-file"
        assert cfg["iceberg_database_raw"] == "raw_v2"

    def test_env_var_overrides_config_file(self, monkeypatch, tmp_path):
        config_data = {"s3_raw_bucket": "from-file"}
        config_file = tmp_path / "config.json"
        config_file.write_text(json.dumps(config_data))

        monkeypatch.setenv(f"{_ENV_PREFIX}S3_RAW_BUCKET", "from-env")
        cfg = get_config(config_path=str(config_file))
        assert cfg["s3_raw_bucket"] == "from-env"
