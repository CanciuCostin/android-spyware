#!/bin/bash
set -e

# Blue-Green Deployment Script
# Usage: ./deploy_blue_green.sh <version>

VERSION=${1:-latest}
CURRENT_ENV=$(docker ps --filter "name=eaglespy-prod" --format "{{.Names}}" | grep -o "blue\|green" || echo "blue")
NEW_ENV=$([[ "$CURRENT_ENV" == "blue" ]] && echo "green" || echo "blue")

echo "🔵 Current environment: $CURRENT_ENV"
echo "🟢 Deploying to: $NEW_ENV"

# Pull new image
echo "📥 Pulling image version: $VERSION"
docker pull eaglespy:$VERSION

# Start new environment
echo "🚀 Starting $NEW_ENV environment..."
docker-compose -f docker-compose.${NEW_ENV}.yml up -d

# Wait for health check
echo "🏥 Waiting for health check..."
for i in {1..30}; do
  if curl -sf http://localhost:${NEW_ENV_PORT:-3001}/health > /dev/null; then
    echo "✅ Health check passed!"
    break
  fi
  echo "⏳ Waiting... ($i/30)"
  sleep 2
done

# Run smoke tests
echo "🧪 Running smoke tests..."
./scripts/smoke_test.sh http://localhost:${NEW_ENV_PORT:-3001}

# Switch traffic (update load balancer/nginx)
echo "🔄 Switching traffic to $NEW_ENV..."
./scripts/switch_traffic.sh $NEW_ENV

# Wait for traffic drain
echo "⏳ Draining traffic from $CURRENT_ENV..."
sleep 10

# Stop old environment
echo "🛑 Stopping $CURRENT_ENV environment..."
docker-compose -f docker-compose.${CURRENT_ENV}.yml down

echo "✅ Deployment complete! Active environment: $NEW_ENV"
