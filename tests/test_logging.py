"""Unit tests for core.logging module."""

import logging

from core.logging.logger import get_logger


class TestGetLogger:
    """Tests for the get_logger() factory."""

    def test_returns_logger_with_correct_name(self):
        logger = get_logger("test.module.alpha")
        assert logger.name == "test.module.alpha"

    def test_default_level_is_info(self, monkeypatch):
        monkeypatch.delenv("LOG_LEVEL", raising=False)
        logger = get_logger("test.module.beta")
        assert logger.level == logging.INFO

    def test_level_from_env(self, monkeypatch):
        monkeypatch.setenv("LOG_LEVEL", "DEBUG")
        logger = get_logger("test.module.gamma")
        assert logger.level == logging.DEBUG

    def test_explicit_level_overrides_env(self, monkeypatch):
        monkeypatch.setenv("LOG_LEVEL", "DEBUG")
        logger = get_logger("test.module.delta", level=logging.WARNING)
        assert logger.level == logging.WARNING

    def test_no_duplicate_handlers(self):
        name = "test.module.epsilon"
        logger1 = get_logger(name)
        handler_count = len(logger1.handlers)
        logger2 = get_logger(name)
        assert len(logger2.handlers) == handler_count
