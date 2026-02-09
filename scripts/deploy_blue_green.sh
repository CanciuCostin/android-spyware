#!/bin/bash
set -e

# Blue-Green Deployment Script
# Usage: ./deploy_blue_green.sh <version>

VERSION=${1:-latest}
CURRENT_ENV=$(docker ps --filter "name=eaglespy-prod" --format "{{.Names}}" | grep -o "blue\|green" || echo "blue")
NEW_ENV=$([[ "$CURRENT_ENV" == "blue" ]] && echo "green" || echo "blue")

if [ "$NEW_ENV" = "blue" ]; then
  NEW_PORT=3000
else
  NEW_PORT=3001
fi

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
  if curl -sf http://localhost:${NEW_PORT}/health > /dev/null; then
    echo "✅ Health check passed!"
    break
  fi
  echo "⏳ Waiting... ($i/30)"
  sleep 2
done

# Run smoke tests
echo "🧪 Running smoke tests..."
./scripts/smoke_test.sh http://localhost:${NEW_PORT}

# Switch traffic (update load balancer/nginx)
echo "🔄 Switching traffic to $NEW_ENV..."
./scripts/switch_traffic.sh $NEW_ENV

# Wait for traffic drain
echo "⏳ Draining traffic from $CURRENT_ENV..."
sleep 10

# Rollback on failure
if ! curl -sf "http://localhost:${NEW_PORT}/health" > /dev/null 2>&1; then
  echo "Health check failed! Rolling back..."
  docker-compose -f docker-compose.${NEW_ENV}.yml down
  echo "Rollback complete. ${CURRENT_ENV} still running."
  exit 1
fi

# Stop old environment
echo "🛑 Stopping $CURRENT_ENV environment..."
docker-compose -f docker-compose.${CURRENT_ENV}.yml down

echo "✅ Deployment complete! Active environment: $NEW_ENV"
