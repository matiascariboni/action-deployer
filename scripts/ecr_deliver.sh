#!/bin/bash
set -e

METHOD_UPPER=$(echo "$METHOD" | tr '[:lower:]' '[:upper:]')
if [ "$METHOD_UPPER" != "ECR" ]; then exit 0; fi

if [ ! -f "$IMAGE_TAR_PATH" ]; then
  echo "❌ Image file not found: $IMAGE_TAR_PATH"
  exit 1
fi

SERVICE_NAME=$(basename "$IMAGE_TAR_PATH" .tar)

echo "=== Loading Docker image ==="
docker load -i "$IMAGE_TAR_PATH"

LOCAL_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" "$SERVICE_NAME" | head -n 1)
if [ -z "$LOCAL_IMAGE" ]; then
  echo "❌ Could not resolve loaded image for service: $SERVICE_NAME"
  exit 1
fi
IMAGE_TAG=${LOCAL_IMAGE##*:}
echo "✅ Image loaded: $LOCAL_IMAGE"

echo "=== Resolving AWS account/region ==="
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-$AWS_DEFAULT_REGION}
if [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ]; then
  echo "❌ Could not resolve AWS account/region. Make sure AWS credentials are configured (e.g. via aws-actions/configure-aws-credentials) before this step."
  exit 1
fi
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
echo "Account: $ACCOUNT_ID | Region: $REGION | Registry: $ECR_REGISTRY"

echo "=== Ensuring ECR repository exists ==="
if ! aws ecr describe-repositories --repository-names "$ECR_REPOSITORY" --region "$REGION" >/dev/null 2>&1; then
  echo "Repository '$ECR_REPOSITORY' not found, creating it..."
  aws ecr create-repository --repository-name "$ECR_REPOSITORY" --region "$REGION" >/dev/null
  echo "✅ Repository created"
else
  echo "✅ Repository already exists"
fi

echo "=== Logging in to ECR ==="
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

ECR_IMAGE="$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
echo "=== Tagging and pushing $ECR_IMAGE ==="
docker tag "$LOCAL_IMAGE" "$ECR_IMAGE"
docker push "$ECR_IMAGE"

echo "🎉 Image pushed to ECR: $ECR_IMAGE"
