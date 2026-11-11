"""Structured JSON logging configuration for stdout."""

import logging
import sys
from datetime import UTC, datetime

from pythonjsonlogger import jsonlogger


class CustomJsonFormatter(jsonlogger.JsonFormatter):
    """Custom JSON formatter with standard DevOps logging fields."""

    def add_fields(self, log_record, record, message_dict):
        super().add_fields(log_record, record, message_dict)
        if not log_record.get("timestamp"):
            log_record["timestamp"] = datetime.now(UTC).isoformat()
        if log_record.get("level"):
            log_record["level"] = log_record["level"].upper()
        else:
            log_record["level"] = record.levelname


def setup_logger(log_level: str = "INFO", environment: str = "development") -> logging.Logger:
    """Set up structured JSON logging to stdout."""
    numeric_level = getattr(logging, log_level.upper(), logging.INFO)

    # Configure root logger
    logger = logging.getLogger("care_guide_app")
    logger.setLevel(numeric_level)
    logger.propagate = False

    # Remove any existing handlers
    while logger.handlers:
        logger.handlers.pop()

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(numeric_level)

    formatter = CustomJsonFormatter("%(timestamp)s %(level)s %(name)s %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # Intercept uvicorn loggers to output in JSON
    for uvicorn_logger_name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        u_logger = logging.getLogger(uvicorn_logger_name)
        u_logger.handlers = [handler]
        u_logger.propagate = False

    return logger
