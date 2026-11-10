#!/usr/bin/env bash
# ==============================================================================
# Script to verify zero-downtime rolling update and automatic rollback
# ==============================================================================
set -euo pipefail

DEPLOYMENT_NAME="care-guide-deployment"
NAMESPACE="${1:-default}"

echo "==> Current deployment status in namespace '${NAMESPACE}':"
kubectl rollout status deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"

echo "==> Step 1: Initiating rolling update to version 1.1.0..."
kubectl set image deployment/"${DEPLOYMENT_NAME}" app=ghcr.io/josim/care-guide-service:1.1.0 -n "${NAMESPACE}"

echo "==> Monitoring rollout progress..."
kubectl rollout status deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"

echo "==> Revision history:"
kubectl rollout history deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"

echo "==> Step 2: Simulating broken deployment (non-existent image)..."
kubectl set image deployment/"${DEPLOYMENT_NAME}" app=ghcr.io/josim/care-guide-service:broken-tag -n "${NAMESPACE}"

sleep 5
echo "==> Checking deployment state during failure (existing replicas should remain healthy):"
kubectl get pods -l app.kubernetes.io/name=care-guide-service -n "${NAMESPACE}"

echo "==> Step 3: Rolling back to previous healthy revision..."
kubectl rollout undo deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"

echo "==> Waiting for rollback completion..."
kubectl rollout status deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"

echo "==> Rollback complete! Cluster healthy."
kubectl get pods -l app.kubernetes.io/name=care-guide-service -n "${NAMESPACE}"
