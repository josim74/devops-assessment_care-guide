"""Main FastAPI application module."""

import logging
import time
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from datetime import UTC, datetime

from fastapi import FastAPI, Request, Response, status

from app.src.config import Settings, get_settings
from app.src.logger import setup_logger
from app.src.metrics import (
    ERROR_COUNT,
    REQUEST_COUNT,
    REQUEST_LATENCY,
    get_metrics_payload,
)

settings: Settings = get_settings()
logger: logging.Logger = setup_logger(
    log_level=settings.log_level,
    environment=settings.environment_name,
)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Handle graceful startup and shutdown lifecycle events."""
    logger.info(
        "Application starting up",
        extra={
            "app_version": settings.app_version,
            "environment": settings.environment_name,
            "port": settings.port,
            "log_level": settings.log_level,
        },
    )

    yield

    logger.info(
        "Application shutting down gracefully on SIGTERM/interrupt",
        extra={
            "app_version": settings.app_version,
            "environment": settings.environment_name,
        },
    )


app = FastAPI(
    title="DevOps Candidate Assessment Web Service",
    version=settings.app_version,
    lifespan=lifespan,
)


@app.middleware("http")
async def metrics_and_logging_middleware(request: Request, call_next) -> Response:
    """Instrument HTTP requests with Prometheus metrics and structured JSON logging."""
    start_time = time.perf_counter()
    method = request.method
    path = request.url.path

    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    except Exception as exc:
        logger.error(
            "Unhandled exception occurred while processing request",
            extra={
                "path": path,
                "method": method,
                "error": str(exc),
                "error_type": exc.__class__.__name__,
            },
            exc_info=True,
        )
        raise exc
    finally:
        duration = time.perf_counter() - start_time
        duration_ms = round(duration * 1000, 2)

        # Do not record high cardinality URLs for metrics (normalize endpoints)
        endpoint = path
        # Normalize known endpoints
        if path.startswith("/metrics"):
            endpoint = "/metrics"
        elif path.startswith("/health"):
            endpoint = "/health"
        elif path == "/":
            endpoint = "/"

        # Prometheus metrics recording
        REQUEST_COUNT.labels(
            method=method,
            endpoint=endpoint,
            status_code=str(status_code),
        ).inc()

        REQUEST_LATENCY.labels(
            method=method,
            endpoint=endpoint,
        ).observe(duration)

        if status_code >= 400:
            ERROR_COUNT.labels(
                method=method,
                endpoint=endpoint,
                status_code=str(status_code),
            ).inc()

        # Structured JSON logging to stdout
        log_level = logging.INFO
        if status_code >= 500:
            log_level = logging.ERROR
        elif status_code >= 400:
            log_level = logging.WARNING

        logger.log(
            log_level,
            "HTTP request completed",
            extra={
                "method": method,
                "path": path,
                "status_code": status_code,
                "duration_ms": duration_ms,
                "client_ip": request.client.host if request.client else "unknown",
            },
        )


@app.get("/", status_code=status.HTTP_200_OK)
async def root():
    """Root endpoint returning basic application status and version."""
    return {
        "message": "Hello from DevOps Task!",
        "status": "running",
        "version": settings.app_version,
    }


@app.get("/health", status_code=status.HTTP_200_OK)
async def health():
    """Liveness and readiness health check endpoint."""
    return {
        "status": "healthy",
        "version": settings.app_version,
        "environment": settings.environment_name,
        "timestamp": datetime.now(UTC).isoformat(),
    }


@app.get("/metrics")
async def metrics():
    """Expose Prometheus formatted metrics."""
    payload, content_type = get_metrics_payload()
    return Response(content=payload, media_type=content_type)


def start():
    """Application entry point for running directly or via CLI."""
    import uvicorn

    uvicorn.run(
        "app.src.main:app",
        host="0.0.0.0",
        port=settings.port,
        log_config=None,  # Handled by custom logger
        access_log=False,  # Logged via custom middleware
    )


if __name__ == "__main__":
    start()
