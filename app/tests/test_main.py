"""Unit tests for FastAPI endpoints, metrics, and configuration."""

import pytest
from fastapi.testclient import TestClient

from app.src.main import app, settings


@pytest.fixture
def client():
    """Create a test client instance with lifespan context."""
    with TestClient(app) as test_client:
        yield test_client


def test_root_endpoint(client):
    """Test GET / returns expected message, status, and version."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Hello from DevOps Task!"
    assert data["status"] == "running"
    assert data["version"] == settings.app_version


def test_health_endpoint(client):
    """Test GET /health returns healthy status, version, and timestamp."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data
    assert "environment" in data
    assert "timestamp" in data


def test_metrics_endpoint(client):
    """Test GET /metrics returns Prometheus formatted metrics."""
    # First invoke root to ensure metrics are recorded
    client.get("/")

    response = client.get("/metrics")
    assert response.status_code == 200
    assert "text/plain" in response.headers["content-type"]
    body = response.text

    # Verify required Prometheus metrics are present
    assert "http_requests_total" in body
    assert "http_request_errors_total" in body
    assert "http_request_duration_seconds" in body


def test_error_metrics_on_404(client):
    """Test that 404 responses increment error metrics."""
    not_found_response = client.get("/non-existent-path")
    assert not_found_response.status_code == 404

    metrics_response = client.get("/metrics")
    assert metrics_response.status_code == 200
    assert 'status_code="404"' in metrics_response.text


def test_settings_from_env(monkeypatch):
    """Test that settings load correctly from environment variables."""
    from app.src.config import get_settings

    monkeypatch.setenv("PORT", "9090")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("ENVIRONMENT_NAME", "staging")
    monkeypatch.setenv("APP_VERSION", "2.1.0")

    loaded_settings = get_settings()
    assert loaded_settings.port == 9090
    assert loaded_settings.log_level == "DEBUG"
    assert loaded_settings.environment_name == "staging"
    assert loaded_settings.app_version == "2.1.0"
