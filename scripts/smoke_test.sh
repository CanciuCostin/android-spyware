#!/bin/bash
set -e

BASE_URL=${1:-http://localhost:3000}

echo "🧪 Running smoke tests against: $BASE_URL"

# Test 1: Health endpoint
if curl -sf "$BASE_URL/health" | grep -q "ok"; then
  echo "✅ Health check: PASS"
else
  echo "❌ Health check: FAIL"
  exit 1
fi

# Test 2: Admin login page
if curl -sf "$BASE_URL/admin/login" | grep -q "Sign in"; then
  echo "✅ Admin login: PASS"
else
  echo "❌ Admin login: FAIL"
  exit 1
fi

# Test 3: API health
if curl -sf "$BASE_URL/api/health" | grep -q "status"; then
  echo "✅ API health: PASS"
else
  echo "❌ API health: FAIL"
  exit 1
fi

echo "✅ All smoke tests passed!"
