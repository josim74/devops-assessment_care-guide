"""Configuration management via environment variables."""

import os

from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings read from environment variables."""

    # Server port (reads PORT or APP_PORT)
    port: int = Field(default=8080, validation_alias="PORT")
    # Log level (INFO, DEBUG, WARNING, ERROR, CRITICAL)
    log_level: str = Field(default="INFO", validation_alias="LOG_LEVEL")
    # Environment name (reads ENVIRONMENT_NAME or APP_ENV)
    environment_name: str = Field(default="development", validation_alias="ENVIRONMENT_NAME")
    # Application version
    app_version: str = Field(default="1.0.0", validation_alias="APP_VERSION")

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "extra": "ignore",
    }


def get_settings() -> Settings:
    """Return an instance of application settings with environment variable fallbacks."""
    # Support alternate alias APP_PORT if PORT is not set
    if "PORT" not in os.environ and "APP_PORT" in os.environ:
        os.environ["PORT"] = os.environ["APP_PORT"]

    # Support alternate alias APP_ENV if ENVIRONMENT_NAME is not set
    if "ENVIRONMENT_NAME" not in os.environ and "APP_ENV" in os.environ:
        os.environ["ENVIRONMENT_NAME"] = os.environ["APP_ENV"]

    return Settings()
