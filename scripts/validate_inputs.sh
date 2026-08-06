#!/bin/bash
set -e

ACTION_UPPER=$(echo "$ACTION" | tr '[:lower:]' '[:upper:]')
METHOD_UPPER=$(echo "$METHOD" | tr '[:lower:]' '[:upper:]')

echo "Method: $METHOD_UPPER | Target: $EC2_USER@$EC2_IP"
echo "Image: $IMAGE_TAR_PATH | Dockerfile: $DOCKERFILE_PATH"
echo "Action: ${ACTION_UPPER:-<both>}"

if [ -z "$METHOD_UPPER" ]; then
  echo "❌ METHOD missing"
  exit 1
fi

if [ "$METHOD_UPPER" != "EC2" ] && [ "$METHOD_UPPER" != "ECR" ]; then
  echo "❌ METHOD must be either 'EC2' or 'ECR', got: '$METHOD'"
  exit 1
fi

if [ "$METHOD_UPPER" = "EC2" ]; then
  if [ -z "$EC2_IP" ]; then
    echo "❌ EC2_IP missing"
    exit 1
  fi

  if [ -z "$EC2_USER" ]; then
    echo "❌ EC2_USER missing"
    exit 1
  fi

  if [ -z "$EC2_KEY" ]; then
    echo "❌ EC2_KEY missing"
    exit 1
  fi
fi

if [ "$METHOD_UPPER" = "ECR" ] && [ -z "$ECR_REPOSITORY" ]; then
  echo "❌ ECR_REPOSITORY missing"
  exit 1
fi

if [ -z "$IMAGE_TAR_PATH" ]; then
  echo "❌ IMAGE_TAR_PATH missing"
  exit 1
fi

case "$IMAGE_TAR_PATH" in
  /*) ;;
  *)
    echo "❌ IMAGE_TAR_PATH must be an absolute path, got: '$IMAGE_TAR_PATH'"
    exit 1
    ;;
esac

if [ -n "$ACTION_UPPER" ] && [ "$ACTION_UPPER" != "DELIVER" ] && [ "$ACTION_UPPER" != "DEPLOY" ]; then
  echo "❌ ACTION must be either 'DELIVER' or 'DEPLOY' (or omitted to do both), got: '$ACTION'"
  exit 1
fi

echo "ACTION=$ACTION_UPPER" >> $GITHUB_OUTPUT
echo "✅ Inputs validated"
