#!/usr/bin/env pwsh
# CI/CD Validation Script
# Validates that all CI/CD components are properly configured

Write-Host "🔍 Validating CI/CD Configuration..." -ForegroundColor Cyan
Write-Host ""

$errors = 0
$warnings = 0

# Check GitHub Workflows
Write-Host "📋 Checking GitHub Workflows..." -ForegroundColor Yellow
$workflows = @(
    ".github/workflows/security-scan.yml",
    ".github/workflows/release.yml"
)

foreach ($workflow in $workflows) {
    if (Test-Path $workflow) {
        Write-Host "  ✅ Found: $workflow" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Missing: $workflow" -ForegroundColor Red
        $errors++
    }
}

# Check Dependabot Configuration
Write-Host ""
Write-Host "🤖 Checking Dependabot Configuration..." -ForegroundColor Yellow
if (Test-Path ".github/dependabot.yml") {
    Write-Host "  ✅ Found: .github/dependabot.yml" -ForegroundColor Green
    
    $content = Get-Content ".github/dependabot.yml" -Raw
    $ecosystems = @("bundler", "npm", "docker", "github-actions")
    
    foreach ($ecosystem in $ecosystems) {
        if ($content -match $ecosystem) {
            Write-Host "  ✅ Configured: $ecosystem" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Missing: $ecosystem" -ForegroundColor Yellow
            $warnings++
        }
    }
} else {
    Write-Host "  ❌ Missing: .github/dependabot.yml" -ForegroundColor Red
    $errors++
}

# Check Deployment Scripts
Write-Host ""
Write-Host "🚀 Checking Deployment Scripts..." -ForegroundColor Yellow
$scripts = @(
    "scripts/deploy_blue_green.sh",
    "scripts/smoke_test.sh",
    "scripts/switch_traffic.sh"
)

foreach ($script in $scripts) {
    if (Test-Path $script) {
        Write-Host "  ✅ Found: $script" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Missing: $script" -ForegroundColor Red
        $errors++
    }
}

# Check Docker Compose Files
Write-Host ""
Write-Host "🐳 Checking Docker Compose Files..." -ForegroundColor Yellow
$composeFiles = @(
    "docker-compose.blue.yml",
    "docker-compose.green.yml"
)

foreach ($file in $composeFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ Found: $file" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Missing: $file" -ForegroundColor Red
        $errors++
    }
}

# Check Documentation
Write-Host ""
Write-Host "📚 Checking Documentation..." -ForegroundColor Yellow
$docs = @(
    "CI_CD_GUIDE.md",
    "scripts/CI_CD_REFERENCE.md"
)

foreach ($doc in $docs) {
    if (Test-Path $doc) {
        Write-Host "  ✅ Found: $doc" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Missing: $doc" -ForegroundColor Yellow
        $warnings++
    }
}

# Check Environment Variables
Write-Host ""
Write-Host "🔑 Checking Required Environment Variables..." -ForegroundColor Yellow
$requiredEnvVars = @(
    "DATABASE_URL",
    "REDIS_URL",
    "SECRET_KEY_BASE"
)

foreach ($var in $requiredEnvVars) {
    $value = [Environment]::GetEnvironmentVariable($var)
    if ($value) {
        Write-Host "  ✅ Set: $var" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Not set: $var" -ForegroundColor Yellow
        $warnings++
    }
}

# Check Docker Secrets (for CI/CD)
Write-Host ""
Write-Host "🔐 Required GitHub Secrets (must be configured manually)..." -ForegroundColor Yellow
$requiredSecrets = @(
    "DOCKER_USERNAME",
    "DOCKER_PASSWORD",
    "DOCKER_REGISTRY"
)

foreach ($secret in $requiredSecrets) {
    Write-Host "  ℹ️  Required: $secret" -ForegroundColor Cyan
}
Write-Host "  📝 Configure at: Settings > Secrets and variables > Actions" -ForegroundColor Gray

# Check Tools
Write-Host ""
Write-Host "🛠️  Checking Available Tools..." -ForegroundColor Yellow

# Docker
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "  ✅ Docker installed" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Docker not found" -ForegroundColor Yellow
    $warnings++
}

# Docker Compose
if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    Write-Host "  ✅ Docker Compose installed" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Docker Compose not found" -ForegroundColor Yellow
    $warnings++
}

# Ruby
if (Get-Command ruby -ErrorAction SilentlyContinue) {
    $rubyVersion = ruby --version
    Write-Host "  ✅ Ruby installed: $rubyVersion" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Ruby not found" -ForegroundColor Yellow
    $warnings++
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host "📊 Validation Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Gray

if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Host "✅ All checks passed! CI/CD configuration is complete." -ForegroundColor Green
} elseif ($errors -eq 0) {
    Write-Host "⚠️  Configuration complete with $warnings warning(s)." -ForegroundColor Yellow
    Write-Host "   Review warnings above and configure as needed." -ForegroundColor Yellow
} else {
    Write-Host "❌ Configuration incomplete: $errors error(s), $warnings warning(s)." -ForegroundColor Red
    Write-Host "   Fix errors above before proceeding." -ForegroundColor Red
}

Write-Host ""
Write-Host "📖 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Configure GitHub Secrets (DOCKER_USERNAME, DOCKER_PASSWORD, DOCKER_REGISTRY)" -ForegroundColor Gray
Write-Host "  2. Enable GitHub Actions in repository settings" -ForegroundColor Gray
Write-Host "  3. Enable GitHub Security features (Code scanning, Dependabot)" -ForegroundColor Gray
Write-Host "  4. Review CI_CD_GUIDE.md for detailed setup instructions" -ForegroundColor Gray
Write-Host ""

exit $errors
