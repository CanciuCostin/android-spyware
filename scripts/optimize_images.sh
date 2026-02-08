#!/bin/bash
# Docker Image Optimization and Analysis Script
# Usage: ./scripts/optimize_images.sh

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Docker Image Optimization Script${NC}"
echo "========================================"
echo ""

# Function to analyze image size
analyze_image() {
  IMAGE=$1
  echo -e "${YELLOW}📦 Analyzing: ${IMAGE}${NC}"
  
  if docker images ${IMAGE} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -v REPOSITORY; then
    SIZE=$(docker images ${IMAGE} --format "{{.Size}}")
    echo -e "   Size: ${GREEN}${SIZE}${NC}"
    
    # Count layers
    LAYERS=$(docker history ${IMAGE} --no-trunc --format "{{.CreatedBy}}" | wc -l)
    echo -e "   Layers: ${LAYERS}"
    
    # Use dive for detailed analysis (if installed)
    if command -v dive &> /dev/null; then
      echo "   Running dive analysis..."
      dive ${IMAGE} --ci --lowestEfficiency=0.90 --highestWastedBytes=50MB || echo "   Warning: Dive detected inefficiencies"
    fi
  else
    echo -e "   ${YELLOW}Image not found${NC}"
  fi
  echo ""
}

# Function to build and tag images
build_images() {
  echo -e "${BLUE}🏗️  Building optimized images...${NC}"
  echo ""
  
  # Build Rails app
  echo "Building Rails application..."
  docker build -t eaglespy-rails:latest -f docker/app-rails-server/Dockerfile .
  
  # Build Frontend
  if [ -f "frontend/Dockerfile" ]; then
    echo "Building Frontend application..."
    docker build -t eaglespy-frontend:latest -f frontend/Dockerfile ./frontend
  fi
  
  echo -e "${GREEN}✅ Build complete${NC}"
  echo ""
}

# Function to compare sizes
compare_sizes() {
  echo -e "${BLUE}📊 Image Size Comparison${NC}"
  echo "=========================="
  docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep -E "(REPOSITORY|eaglespy|postgres|redis|coturn|jaeger)"
  echo ""
}

# Function to scan for vulnerabilities (if trivy is installed)
scan_security() {
  if command -v trivy &> /dev/null; then
    echo -e "${BLUE}🔒 Security Scanning${NC}"
    echo "===================="
    trivy image --severity HIGH,CRITICAL eaglespy-rails:latest
    echo ""
  fi
}

# Function to cleanup
cleanup_images() {
  echo -e "${BLUE}🧹 Cleaning up unused Docker resources...${NC}"
  
  # Remove dangling images
  docker image prune -f
  
  # Remove unused build cache (be careful with this in CI/CD)
  # docker builder prune -f
  
  echo -e "${GREEN}✅ Cleanup complete${NC}"
  echo ""
}

# Function to show optimization tips
show_tips() {
  echo -e "${BLUE}💡 Optimization Tips${NC}"
  echo "===================="
  echo "1. Multi-stage builds reduce final image size by 50-70%"
  echo "2. Use alpine-based images for minimal footprint"
  echo "3. Remove build dependencies in final stage"
  echo "4. Clean package manager caches"
  echo "5. Use .dockerignore to exclude unnecessary files"
  echo "6. Combine RUN commands to reduce layers"
  echo "7. Order COPY commands by change frequency (dependencies first)"
  echo ""
}

# Main execution
main() {
  case "${1:-all}" in
    build)
      build_images
      ;;
    analyze)
      analyze_image "eaglespy-rails:latest"
      analyze_image "eaglespy-frontend:latest"
      analyze_image "postgres:13-alpine"
      analyze_image "redis:7-alpine"
      ;;
    compare)
      compare_sizes
      ;;
    security)
      scan_security
      ;;
    clean)
      cleanup_images
      ;;
    all)
      build_images
      compare_sizes
      analyze_image "eaglespy-rails:latest"
      analyze_image "eaglespy-frontend:latest"
      scan_security
      cleanup_images
      show_tips
      ;;
    *)
      echo "Usage: $0 {build|analyze|compare|security|clean|all}"
      exit 1
      ;;
  esac
  
  echo -e "${GREEN}✅ Docker optimization complete!${NC}"
}

# Run main function
main "$@"
