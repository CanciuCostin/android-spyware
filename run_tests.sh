#!/usr/bin/env bash
# EagleSpy V5 - Test Runner Script
# This script helps run the comprehensive test suite

set -e

echo "=================================="
echo "EagleSpy V5 Test Suite Runner"
echo "=================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Ruby version
REQUIRED_RUBY="2.6.6"
CURRENT_RUBY=$(ruby --version | grep -oP '\d+\.\d+\.\d+' | head -1)

echo -e "${YELLOW}Checking Ruby version...${NC}"
if [[ "$CURRENT_RUBY" != "$REQUIRED_RUBY"* ]]; then
    echo -e "${RED}⚠ Warning: Ruby $REQUIRED_RUBY required, found $CURRENT_RUBY${NC}"
    echo "Install correct version with:"
    echo "  rbenv install $REQUIRED_RUBY && rbenv local $REQUIRED_RUBY"
    echo "  OR"
    echo "  rvm install $REQUIRED_RUBY && rvm use $REQUIRED_RUBY"
    echo ""
fi

# Check if bundle is installed
if ! command -v bundle &> /dev/null; then
    echo -e "${RED}✗ Bundler not found${NC}"
    echo "Install with: gem install bundler:2.1.4"
    exit 1
fi

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
bundle install --quiet

# Setup test database
echo -e "${YELLOW}Preparing test database...${NC}"
RAILS_ENV=test bundle exec rails db:test:prepare

# Run tests based on argument
case "${1:-all}" in
    "all")
        echo -e "${GREEN}Running all tests...${NC}"
        bundle exec rspec
        ;;
    
    "connection")
        echo -e "${GREEN}Running connection tests...${NC}"
        bundle exec rspec spec/channels/connection_spec.rb
        ;;
    
    "file-transfers")
        echo -e "${GREEN}Running file transfer tests...${NC}"
        bundle exec rspec spec/controllers/file_transfers_controller_spec.rb
        ;;
    
    "commands")
        echo -e "${GREEN}Running command tests...${NC}"
        bundle exec rspec spec/controllers/concerns/command_sender_spec.rb
        bundle exec rspec spec/services/device_command_service_spec.rb
        ;;
    
    "processors")
        echo -e "${GREEN}Running response processor tests...${NC}"
        bundle exec rspec spec/services/response_processors/
        ;;
    
    "coverage")
        echo -e "${GREEN}Running tests with coverage report...${NC}"
        bundle exec rspec
        echo ""
        echo -e "${GREEN}Opening coverage report...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open coverage/index.html
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            xdg-open coverage/index.html
        elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
            start coverage/index.html
        fi
        ;;
    
    "fast")
        echo -e "${GREEN}Running fast tests only...${NC}"
        bundle exec rspec --tag ~slow
        ;;
    
    "failed")
        echo -e "${GREEN}Re-running failed tests...${NC}"
        bundle exec rspec --only-failures
        ;;
    
    "help")
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  all            - Run all tests (default)"
        echo "  connection     - Run connection authentication tests"
        echo "  file-transfers - Run file transfer controller tests"
        echo "  commands       - Run command sender and service tests"
        echo "  processors     - Run response processor tests"
        echo "  coverage       - Run tests and open coverage report"
        echo "  fast           - Run fast tests only (exclude slow tests)"
        echo "  failed         - Re-run only failed tests"
        echo "  help           - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0               # Run all tests"
        echo "  $0 connection    # Run connection tests"
        echo "  $0 coverage      # Run with coverage"
        ;;
    
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✓ Test run complete!${NC}"
