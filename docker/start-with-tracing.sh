#!/bin/bash
# Quick Start: Tracing & Observability

set -e

echo "🚀 Starting android-spyware with Tracing & Observability..."
echo ""

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Docker is running
echo -e "${BLUE}📦 Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker Desktop.${NC}"
    exit 1
fi

if ! docker ps &> /dev/null; then
    echo -e "${RED}❌ Docker daemon not running. Please start Docker Desktop.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# Stop existing containers
echo -e "${YELLOW}⏹️  Stopping existing containers...${NC}"
docker compose down 2>/dev/null || true
sleep 2

# Start containers with tracing
echo -e "${BLUE}🚀 Starting containers with Jaeger tracing...${NC}"
docker compose up -d

# Wait for services to start
echo -e "${YELLOW}⏳ Waiting for services to start (45 seconds)...${NC}"
sleep 45

# Check container status
echo -e "${BLUE}📊 Container Status:${NC}"
docker compose ps

echo ""
echo -e "${GREEN}✅ Services started successfully!${NC}"
echo ""

# Display access information
echo -e "${BLUE}🌐 Service URLs:${NC}"
echo -e "  ${GREEN}Rails Admin UI:${NC}  http://localhost:9000/admin"
echo -e "  ${GREEN}Jaeger Traces:${NC}   http://localhost:16686"
echo -e "  ${GREEN}Database:${NC}        localhost:5432 (postgres)"
echo -e "  ${GREEN}Metasploit RPC:${NC}  localhost:3333"
echo ""

echo -e "${BLUE}👤 Default Credentials:${NC}"
echo -e "  ${GREEN}Admin Email:${NC}     admin@example.com"
echo -e "  ${GREEN}Admin Password:${NC}  password"
echo ""

echo -e "${BLUE}📋 Next Steps:${NC}"
echo "  1. Open http://localhost:9000/admin in your browser"
echo "  2. Login with admin credentials"
echo "  3. Generate an APK payload"
echo "  4. Watch traces appear in http://localhost:16686"
echo ""

echo -e "${BLUE}📚 Documentation:${NC}"
echo "  See docs/TRACING_GUIDE.md for detailed tracing documentation"
echo ""

# Tail logs
echo -e "${YELLOW}📝 Rails Logs (Ctrl+C to stop):${NC}"
docker compose logs -f rails-app
