#!/usr/bin/env bash
# Initial deployment script for the Player Portal widget.
# Run this AFTER terraform apply has provisioned the ECR repos and Lambdas.
#
# Prerequisites:
#   - AWS CLI configured with admin/deploy credentials
#   - Docker buildx with QEMU arm64 support (docker run --rm --privileged multiarch/qemu-user-static --reset -p yes)
#   - slugger-player-portal and Terraform-infrastructure repos checked out
#
# Usage:
#   cd /path/to/slugger-player-portal
#   bash /path/to/Terraform-infrastructure/widgets/player-portal/scripts/initial-deploy.sh

set -euo pipefail

AWS_REGION="us-east-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

echo "▶  Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_BASE"

echo "▶  Building and pushing player-portal-api image (arm64)..."
docker buildx build \
  --platform linux/arm64 \
  -f docker/Dockerfile.api \
  -t "$ECR_BASE/player-portal-api:latest" \
  --push \
  .

echo "▶  Fetching NEXT_PUBLIC_API_URL from SSM..."
NEXT_PUBLIC_API_URL=$(aws ssm get-parameter \
  --name /slugger/player-portal/api-url-public \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text)

echo "▶  Building and pushing player-portal-web image (arm64)..."
docker buildx build \
  --platform linux/arm64 \
  -f docker/Dockerfile.web \
  --build-arg "NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL" \
  --build-arg "NEXT_PUBLIC_BASE_PATH=/widgets/player-portal" \
  -t "$ECR_BASE/player-portal-web:latest" \
  --push \
  .

echo "▶  Updating Lambda function code..."
aws lambda update-function-code \
  --function-name player-portal-api \
  --image-uri "$ECR_BASE/player-portal-api:latest" \
  --architectures arm64

aws lambda update-function-code \
  --function-name player-portal-web \
  --image-uri "$ECR_BASE/player-portal-web:latest" \
  --architectures arm64

aws lambda update-function-code \
  --function-name player-portal-sync \
  --image-uri "$ECR_BASE/player-portal-api:latest" \
  --architectures arm64

echo "▶  Waiting for Lambda updates to stabilize..."
aws lambda wait function-updated --function-name player-portal-api
aws lambda wait function-updated --function-name player-portal-web
aws lambda wait function-updated --function-name player-portal-sync

echo "▶  Triggering initial TBC sync to populate the database..."
aws lambda invoke \
  --function-name player-portal-sync \
  --log-type Tail \
  /tmp/player-portal-sync-result.json

echo "▶  Sync result:"
cat /tmp/player-portal-sync-result.json

echo ""
echo "▶  Smoke-testing the API health endpoint..."
curl --fail --silent --show-error \
  "https://alpb-analytics.com/widgets/player-portal/api/health"

echo ""
echo "✓  Initial deployment complete."
echo "   Next step: run backend/db/seed-player-portal.js in the slugger-website repo"
echo "   to register the widget in the SLUGGER dashboard."
