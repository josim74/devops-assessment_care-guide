# syntax=docker/dockerfile:1
# ------------------------------------------------------------------------------
# Stage 1: Build stage (compile wheels and install dependencies)
# ------------------------------------------------------------------------------
FROM python:3.12.4-alpine3.20 AS builder

WORKDIR /build

# Install build dependencies if needed for compiling packages
# Builder stage is discarded; pinning alpine package revisions here is brittle (they are
# removed from the mirror) and does not affect the shipped image.
# hadolint ignore=DL3018
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    linux-headers \
    libffi-dev

# Install dependencies into a wheels cache
COPY app/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip==24.1.2 && \
    pip wheel --no-cache-dir --wheel-dir=/build/wheels -r requirements.txt

# ------------------------------------------------------------------------------
# Stage 2: Final minimal production image
# ------------------------------------------------------------------------------
FROM python:3.12.4-alpine3.20 AS runner

ARG APP_VERSION=1.0.0

# OpenContainer Initiative (OCI) metadata labels
LABEL org.opencontainers.image.title="devops-assessment-service" \
      org.opencontainers.image.description="Production-ready FastAPI service with Prometheus metrics & JSON logging" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.vendor="DevOps Assessment" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/josim/devops-assessment_care-guide"

# Prevent Python from writing .pyc files and enable unbuffered logging to stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    APP_VERSION=${APP_VERSION} \
    PORT=8080 \
    LOG_LEVEL=INFO \
    ENVIRONMENT_NAME=production

WORKDIR /app

# Create unprivileged non-root user and group (UID/GID 10001)
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup -s /sbin/nologin -D

# Install wheels from builder stage
COPY --from=builder /build/wheels /wheels
RUN pip install --no-cache-dir /wheels/* && \
    rm -rf /wheels

# Copy application source code with proper non-root permissions
COPY --chown=appuser:appgroup app/src /app/app/src

# Switch to unprivileged non-root user
USER 10001:10001

# Expose service port
EXPOSE 8080

# Production container healthcheck using Alpine's built-in wget
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1

# Launch service with python module
ENTRYPOINT ["python3", "-m", "app.src.main"]
