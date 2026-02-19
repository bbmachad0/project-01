"""Runtime configuration resolver.

Loads configuration values from (in order of precedence):
1. Explicit keyword arguments
2. Environment variables (``{ABBR}_<KEY>``, derived from setup/domain.json)
3. A YAML / JSON config file pointed to by ``CONFIG_PATH``
4. Defaults derived from ``setup/domain.json``

This keeps every job free of environment-specific literals.

Bucket naming convention:  {domain_abbr}-{purpose}-{account_id}-{env}
Example:                   f01-raw-390403879405-dev

Usage::

    from core.config.settings import get_config
    cfg = get_config()
    raw_bucket = cfg["s3_raw_bucket"]
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


def _load_domain() -> dict[str, str]:
    """Read domain.json from setup/ directory (best-effort)."""
    candidates = [
        Path(__file__).resolve().parents[3]
        / "setup"
        / "domain.json",  # src/core/config -> repo root/setup
        Path.cwd() / "setup" / "domain.json",
        # Fallback: legacy location at repo root
        Path(__file__).resolve().parents[3] / "domain.json",
        Path.cwd() / "domain.json",
    ]
    for p in candidates:
        if p.is_file():
            with p.open() as f:
                return json.load(f)
    return {}


def _resolve_account_id() -> str:
    """Best-effort AWS Account ID resolution for bucket naming.

    Returns the account ID from:
    1. AWS_ACCOUNT_ID environment variable (set by bootstrap or .env)
    2. STS call (requires valid AWS credentials)
    3. Empty string as fallback (local dev without AWS)
    """
    acct = os.getenv("AWS_ACCOUNT_ID", "")
    if acct:
        return acct
    try:
        import boto3

        sts = boto3.client("sts")
        return sts.get_caller_identity()["Account"]
    except Exception:
        return ""


_DOMAIN = _load_domain()
_ABBR = _DOMAIN.get("domain_abbr", "xx")
_ENV_PREFIX = f"{_ABBR.upper().replace('-', '_')}_"
_ACCOUNT_ID = _resolve_account_id()


def _bucket_name(purpose: str) -> str:
    """Build bucket name following AWS convention: {abbr}-{purpose}-{account_id}-{env}.

    For local development without AWS credentials, falls back to
    ``{abbr}-{purpose}-local`` so settings still load.
    """
    if _ACCOUNT_ID:
        return f"{_ABBR}-{purpose}-{_ACCOUNT_ID}-local"
    return f"{_ABBR}-{purpose}-local"


_DEFAULTS: dict[str, str] = {
    "env": "local",
    "s3_raw_bucket": _bucket_name("raw"),
    "s3_refined_bucket": _bucket_name("refined"),
    "s3_curated_bucket": _bucket_name("curated"),
    "s3_artifacts_bucket": _bucket_name("artifacts"),
    "iceberg_database_raw": f"{_ABBR.replace('-', '_')}_raw",
    "iceberg_database_refined": f"{_ABBR.replace('-', '_')}_refined",
    "iceberg_database_curated": f"{_ABBR.replace('-', '_')}_curated",
    "glue_catalog_id": _ACCOUNT_ID,
    "account_id": _ACCOUNT_ID,
    "log_level": "INFO",
}


def _load_config_file(path: str | None = None) -> dict[str, Any]:
    """Load an optional JSON or YAML config file."""
    config_path = path or os.getenv("CONFIG_PATH")
    if not config_path:
        return {}

    p = Path(config_path)
    if not p.exists():
        return {}

    text = p.read_text()

    if p.suffix in (".yaml", ".yml"):
        try:
            import yaml  # optional dependency

            return yaml.safe_load(text) or {}
        except ImportError:
            return {}

    return json.loads(text)


def get_config(
    config_path: str | None = None,
    **overrides: Any,
) -> dict[str, Any]:
    """Return a merged configuration dictionary.

    Parameters
    ----------
    config_path:
        Path to an optional JSON/YAML config file.
    **overrides:
        Explicit overrides that take highest precedence.
    """
    cfg: dict[str, Any] = dict(_DEFAULTS)

    # Layer 1 - config file
    cfg.update(_load_config_file(config_path))

    # Layer 2 - environment variables
    for key in list(_DEFAULTS):
        env_val = os.getenv(f"{_ENV_PREFIX}{key.upper()}")
        if env_val is not None:
            cfg[key] = env_val

    # The generic ENV variable is a common shorthand
    env_override = os.getenv("ENV")
    if env_override:
        cfg["env"] = env_override.lower()

    # Layer 3 - explicit overrides
    cfg.update(overrides)

    # Rebuild bucket names when env is resolved and account_id is known.
    # This ensures non-local environments get correct bucket names
    # following the convention: {abbr}-{purpose}-{account_id}-{env}
    env = cfg["env"]
    acct = cfg.get("account_id", _ACCOUNT_ID)
    if acct and env != "local":
        for purpose, key in [
            ("raw", "s3_raw_bucket"),
            ("refined", "s3_refined_bucket"),
            ("curated", "s3_curated_bucket"),
            ("artifacts", "s3_artifacts_bucket"),
        ]:
            # Only override if the user hasn't explicitly set a value
            if key not in overrides and not os.getenv(f"{_ENV_PREFIX}{key.upper()}"):
                cfg[key] = f"{_ABBR}-{purpose}-{acct}-{env}"

    return cfg
