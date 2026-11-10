#!/usr/bin/env bash
# ==============================================================================
# EC2 Bootstrap Script: Install Docker, Configure CloudWatch, Run Container
# ==============================================================================
set -euo pipefail

exec > >(tee /var/log/user_data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "==> Starting bootstrap script execution at $(date -u)"

# 1. Update OS and install prerequisites
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release jq awscli

# 2. Install Docker Engine
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

systemctl enable docker
systemctl start docker

# 3. Create deployment directory and deployment script for SSM automation
mkdir -p /opt/care-guide
cat << 'EOF' > /opt/care-guide/deploy.sh
#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="$${1:-latest}"
LOG_GROUP="$${2:-/aws/ec2/staging-care-guide-service}"
AWS_REGION="$${3:-us-east-1}"
CONTAINER_NAME="care-guide-service"
CURRENT_TAG_FILE="/opt/care-guide/current_tag"

PREVIOUS_TAG=""
if [ -f "$CURRENT_TAG_FILE" ]; then
    PREVIOUS_TAG=$(cat "$CURRENT_TAG_FILE")
fi

echo "==> Deploying image: $${IMAGE_TAG}"
echo "==> Previous known tag: $${PREVIOUS_TAG}"

# Pull new image
docker pull "$${IMAGE_TAG}"

# Stop and remove existing container if running
docker stop "$${CONTAINER_NAME}" || true
docker rm "$${CONTAINER_NAME}" || true

# Run new container with AWS CloudWatch logs driver
docker run -d \
  --name "$${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p 8080:8080 \
  -e PORT=8080 \
  -e LOG_LEVEL=INFO \
  -e ENVIRONMENT_NAME=production \
  --log-driver="awslogs" \
  --log-opt awslogs-region="$${AWS_REGION}" \
  --log-opt awslogs-group="$${LOG_GROUP}" \
  --log-opt awslogs-stream="container-$${CONTAINER_NAME}" \
  "$${IMAGE_TAG}"

# Smoke test /health endpoint (retry loop up to 30s)
echo "==> Executing /health smoke test..."
SMOKE_SUCCESS=0
for i in {1..10}; do
    if curl --silent --fail http://127.0.0.1:8080/health | grep -q '"status":"healthy"'; then
        echo "==> Smoke test PASSED on attempt $${i}!"
        SMOKE_SUCCESS=1
        break
    fi
    echo "Waiting for health check... (attempt $${i}/10)"
    sleep 3
done

if [ "$SMOKE_SUCCESS" -ne 1 ]; then
    echo "==> CRITICAL: Smoke test FAILED! Initiating automatic rollback..."
    if [ -n "$PREVIOUS_TAG" ]; then
        docker stop "$${CONTAINER_NAME}" || true
        docker rm "$${CONTAINER_NAME}" || true
        docker run -d \
          --name "$${CONTAINER_NAME}" \
          --restart unless-stopped \
          -p 8080:8080 \
          -e PORT=8080 \
          -e LOG_LEVEL=INFO \
          --log-driver="awslogs" \
          --log-opt awslogs-region="$${AWS_REGION}" \
          --log-opt awslogs-group="$${LOG_GROUP}" \
          --log-opt awslogs-stream="container-$${CONTAINER_NAME}" \
          "$${PREVIOUS_TAG}"
        echo "==> Rolled back to previous tag: $${PREVIOUS_TAG}"
    fi
    exit 1
fi

# Persist successful tag
echo "$${IMAGE_TAG}" > "$CURRENT_TAG_FILE"
echo "==> Deployment successfully finished for $${IMAGE_TAG}"
EOF

chmod +x /opt/care-guide/deploy.sh

# 4. Run initial deployment
/opt/care-guide/deploy.sh "${container_image}" "${log_group_name}" "${aws_region}" || true

echo "==> Bootstrap completed successfully at $(date -u)"
