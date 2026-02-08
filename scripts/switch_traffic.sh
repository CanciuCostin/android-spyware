#!/bin/bash
set -e

# Traffic Switching Script for Blue-Green Deployment
# Usage: ./switch_traffic.sh <blue|green>

NEW_ENV=$1

if [[ "$NEW_ENV" != "blue" && "$NEW_ENV" != "green" ]]; then
  echo "❌ Error: Invalid environment. Use 'blue' or 'green'"
  exit 1
fi

echo "🔄 Switching traffic to $NEW_ENV environment..."

# Determine port based on environment
if [[ "$NEW_ENV" == "blue" ]]; then
  NEW_PORT=3000
else
  NEW_PORT=3001
fi

# Update nginx configuration (if using nginx as load balancer)
if command -v nginx &> /dev/null; then
  echo "📝 Updating nginx configuration..."
  
  # Create nginx config snippet
  cat > /tmp/eaglespy-upstream.conf <<EOF
upstream eaglespy {
    server localhost:${NEW_PORT};
}
EOF
  
  # Copy to nginx config directory (requires sudo)
  if [ -w /etc/nginx/conf.d/ ]; then
    cp /tmp/eaglespy-upstream.conf /etc/nginx/conf.d/eaglespy-upstream.conf
    nginx -t && nginx -s reload
    echo "✅ Nginx configuration updated"
  else
    echo "⚠️  Warning: Cannot write to nginx config. Run with sudo or update manually."
    echo "   Config file: /tmp/eaglespy-upstream.conf"
  fi
fi

# Update HAProxy configuration (if using HAProxy)
if command -v haproxy &> /dev/null; then
  echo "📝 Updating HAProxy configuration..."
  echo "⚠️  HAProxy configuration update not implemented. Update manually."
fi

# Update environment variable for simple proxy
echo "📝 Updating environment variable..."
echo "export EAGLESPY_UPSTREAM_PORT=${NEW_PORT}" > /tmp/eaglespy-env.sh
echo "✅ Environment variable set: EAGLESPY_UPSTREAM_PORT=${NEW_PORT}"

# Update docker-compose proxy if exists
if [ -f "docker-compose.proxy.yml" ]; then
  echo "📝 Updating docker-compose proxy..."
  sed -i.bak "s/UPSTREAM_PORT=.*/UPSTREAM_PORT=${NEW_PORT}/" docker-compose.proxy.yml
  docker-compose -f docker-compose.proxy.yml up -d --no-deps proxy
  echo "✅ Proxy container updated"
fi

echo "✅ Traffic switched to $NEW_ENV environment (port $NEW_PORT)"
