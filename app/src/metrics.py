"""Prometheus metrics collection and instrumentation."""

from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
    Histogram,
    generate_latest,
)

# Shared metrics registry
REGISTRY = CollectorRegistry(auto_describe=True)

# 1. Request count metric
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total count of HTTP requests handled by the service",
    ["method", "endpoint", "status_code"],
    registry=REGISTRY,
)

# 2. Error count metric (status_code >= 400)
ERROR_COUNT = Counter(
    "http_request_errors_total",
    "Total count of HTTP request errors (4xx and 5xx)",
    ["method", "endpoint", "status_code"],
    registry=REGISTRY,
)

# 3. Request latency histogram (seconds)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
    registry=REGISTRY,
)


def get_metrics_payload() -> tuple[bytes, str]:
    """Generate the latest Prometheus metrics payload and content type."""
    return generate_latest(REGISTRY), CONTENT_TYPE_LATEST
