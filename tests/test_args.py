"""Unit tests for dp_foundation.config.args - Glue argument bridge."""

import os
import sys

from dp_foundation.config.args import bridge_glue_args


class TestBridgeGlueArgs:
    """Tests for the bridge_glue_args() function."""

    def test_bridges_key_value_pairs(self, monkeypatch):
        monkeypatch.delenv("ENV", raising=False)
        monkeypatch.delenv("CUSTOM_VAR", raising=False)
        monkeypatch.setattr(
            sys, "argv", ["job.py", "--ENV", "dev", "--CUSTOM_VAR", "hello"]
        )
        bridge_glue_args()
        assert os.environ["ENV"] == "dev"
        assert os.environ["CUSTOM_VAR"] == "hello"
        # Cleanup
        monkeypatch.delenv("ENV", raising=False)
        monkeypatch.delenv("CUSTOM_VAR", raising=False)

    def test_does_not_overwrite_existing_env(self, monkeypatch):
        monkeypatch.setenv("ENV", "prod")
        monkeypatch.setattr(sys, "argv", ["job.py", "--ENV", "dev"])
        bridge_glue_args()
        assert os.environ["ENV"] == "prod"

    def test_skips_orphan_keys(self, monkeypatch):
        """A trailing --KEY without a value should be skipped."""
        monkeypatch.delenv("ORPHAN", raising=False)
        monkeypatch.setattr(sys, "argv", ["job.py", "--ORPHAN"])
        bridge_glue_args()
        assert "ORPHAN" not in os.environ

    def test_ignores_non_dashed_tokens(self, monkeypatch):
        monkeypatch.delenv("FOO", raising=False)
        monkeypatch.setattr(sys, "argv", ["job.py", "positional", "--FOO", "bar"])
        bridge_glue_args()
        assert os.environ.get("FOO") == "bar"
        monkeypatch.delenv("FOO", raising=False)

    def test_no_args_is_noop(self, monkeypatch):
        monkeypatch.setattr(sys, "argv", ["job.py"])
        bridge_glue_args()  # should not raise

    def test_strips_leading_dashes(self, monkeypatch):
        monkeypatch.delenv("ENABLE_METRICS", raising=False)
        monkeypatch.setattr(
            sys, "argv", ["job.py", "--ENABLE_METRICS", "true"]
        )
        bridge_glue_args()
        assert os.environ["ENABLE_METRICS"] == "true"
        monkeypatch.delenv("ENABLE_METRICS", raising=False)
