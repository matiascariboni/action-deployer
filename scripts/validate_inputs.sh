#!/bin/bash
set -e

ACTION_UPPER=$(echo "$ACTION" | tr '[:lower:]' '[:upper:]')

echo "Method: $METHOD | Target: $EC2_USER@$EC2_IP"
echo "Image: $IMAGE_NAME | Dockerfile: $DOCKERFILE_PATH"
echo "Action: ${ACTION_UPPER:-<both>}"

if [ -z "$METHOD" ]; then
  echo "❌ METHOD missing"
  exit 1
fi

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

if [ -z "$IMAGE_NAME" ]; then
  echo "❌ IMAGE_NAME missing"
  exit 1
fi

if [ -n "$ACTION_UPPER" ] && [ "$ACTION_UPPER" != "DELIVER" ] && [ "$ACTION_UPPER" != "DEPLOY" ]; then
  echo "❌ ACTION must be either 'DELIVER' or 'DEPLOY' (or omitted to do both), got: '$ACTION'"
  exit 1
fi

echo "ACTION=$ACTION_UPPER" >> $GITHUB_OUTPUT
echo "✅ Inputs validated"
