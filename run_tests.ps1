# EagleSpy V5 - Test Runner Script (PowerShell)
# This script helps run the comprehensive test suite on Windows

param(
    [string]$TestType = "all"
)

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "EagleSpy V5 Test Suite Runner" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Check Ruby version
$RequiredRuby = "2.6.6"
$CurrentRuby = (ruby --version | Select-String -Pattern '\d+\.\d+\.\d+').Matches[0].Value

Write-Host "Checking Ruby version..." -ForegroundColor Yellow
if ($CurrentRuby -notlike "$RequiredRuby*") {
    Write-Host "⚠ Warning: Ruby $RequiredRuby required, found $CurrentRuby" -ForegroundColor Red
    Write-Host "Install correct version with:" -ForegroundColor Yellow
    Write-Host "  rbenv install $RequiredRuby" -ForegroundColor White
    Write-Host "  OR use RubyInstaller to install $RequiredRuby" -ForegroundColor White
    Write-Host ""
}

# Check if bundle is available
try {
    bundle --version | Out-Null
} catch {
    Write-Host "✗ Bundler not found" -ForegroundColor Red
    Write-Host "Install with: gem install bundler:2.1.4" -ForegroundColor Yellow
    exit 1
}

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
bundle install --quiet

# Setup test database
Write-Host "Preparing test database..." -ForegroundColor Yellow
$env:RAILS_ENV = 'test'
bundle exec rails db:test:prepare

# Run tests based on argument
switch ($TestType) {
    "all" {
        Write-Host "Running all tests..." -ForegroundColor Green
        bundle exec rspec
    }
    
    "connection" {
        Write-Host "Running connection tests..." -ForegroundColor Green
        bundle exec rspec spec\channels\connection_spec.rb
    }
    
    "file-transfers" {
        Write-Host "Running file transfer tests..." -ForegroundColor Green
        bundle exec rspec spec\controllers\file_transfers_controller_spec.rb
    }
    
    "commands" {
        Write-Host "Running command tests..." -ForegroundColor Green
        bundle exec rspec spec\controllers\concerns\command_sender_spec.rb
        bundle exec rspec spec\services\device_command_service_spec.rb
    }
    
    "processors" {
        Write-Host "Running response processor tests..." -ForegroundColor Green
        bundle exec rspec spec\services\response_processors\
    }
    
    "coverage" {
        Write-Host "Running tests with coverage report..." -ForegroundColor Green
        bundle exec rspec
        Write-Host ""
        Write-Host "Opening coverage report..." -ForegroundColor Green
        Start-Process "coverage\index.html"
    }
    
    "fast" {
        Write-Host "Running fast tests only..." -ForegroundColor Green
        bundle exec rspec --tag ~slow
    }
    
    "failed" {
        Write-Host "Re-running failed tests..." -ForegroundColor Green
        bundle exec rspec --only-failures
    }
    
    "help" {
        Write-Host "Usage: .\run_tests.ps1 [option]" -ForegroundColor White
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  all            - Run all tests (default)" -ForegroundColor White
        Write-Host "  connection     - Run connection authentication tests" -ForegroundColor White
        Write-Host "  file-transfers - Run file transfer controller tests" -ForegroundColor White
        Write-Host "  commands       - Run command sender and service tests" -ForegroundColor White
        Write-Host "  processors     - Run response processor tests" -ForegroundColor White
        Write-Host "  coverage       - Run tests and open coverage report" -ForegroundColor White
        Write-Host "  fast           - Run fast tests only (exclude slow tests)" -ForegroundColor White
        Write-Host "  failed         - Re-run only failed tests" -ForegroundColor White
        Write-Host "  help           - Show this help message" -ForegroundColor White
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  .\run_tests.ps1               # Run all tests" -ForegroundColor White
        Write-Host "  .\run_tests.ps1 connection    # Run connection tests" -ForegroundColor White
        Write-Host "  .\run_tests.ps1 coverage      # Run with coverage" -ForegroundColor White
    }
    
    default {
        Write-Host "Unknown option: $TestType" -ForegroundColor Red
        Write-Host "Run '.\run_tests.ps1 help' for usage information" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "✓ Test run complete!" -ForegroundColor Green
