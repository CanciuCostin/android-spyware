# Audit Trail System - Quick Setup Verification
# Run this script after bundle install and db:migrate

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Audit Trail System - Setup Verification" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Check if running from project root
if (-not (Test-Path "Gemfile")) {
    Write-Host "ERROR: Please run this script from the project root directory" -ForegroundColor Red
    exit 1
}

Write-Host "1. Checking Dependencies..." -ForegroundColor Yellow
Write-Host "-" * 80

$gems = @("request_store", "kaminari")
$missingGems = @()

foreach ($gem in $gems) {
    $result = bundle show $gem 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ $gem installed" -ForegroundColor Green
    } else {
        Write-Host "✗ $gem NOT installed" -ForegroundColor Red
        $missingGems += $gem
    }
}

if ($missingGems.Count -gt 0) {
    Write-Host ""
    Write-Host "Missing gems detected. Running bundle install..." -ForegroundColor Yellow
    bundle install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: bundle install failed. Please install manually." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "2. Checking Migration..." -ForegroundColor Yellow
Write-Host "-" * 80

$migrationExists = Test-Path "db\migrate\*_create_audit_trail.rb"
if ($migrationExists) {
    Write-Host "✓ Migration file exists" -ForegroundColor Green
    
    # Check if migration has been run
    $migrationStatus = rails db:migrate:status 2>&1 | Select-String "create_audit_trail"
    if ($migrationStatus) {
        Write-Host "  Status: $migrationStatus"
    }
} else {
    Write-Host "✗ Migration file NOT found" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. Checking Core Files..." -ForegroundColor Yellow
Write-Host "-" * 80

$requiredFiles = @(
    "app\models\audit_log.rb",
    "app\services\audit_service.rb",
    "app\middleware\audit_middleware.rb",
    "app\models\concerns\auditable.rb",
    "app\controllers\audit_logs_controller.rb",
    "config\initializers\audit_trail.rb",
    "lib\tasks\audit_report.rake",
    "AUDIT_TRAIL.md"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✓ $file" -ForegroundColor Green
    } else {
        Write-Host "✗ $file MISSING" -ForegroundColor Red
        $missingFiles += $file
    }
}

Write-Host ""
Write-Host "4. Checking Routes..." -ForegroundColor Yellow
Write-Host "-" * 80

$routesContent = Get-Content "config\routes.rb" -Raw
if ($routesContent -match "audit_logs") {
    Write-Host "✓ Audit logs routes configured" -ForegroundColor Green
} else {
    Write-Host "✗ Audit logs routes NOT configured" -ForegroundColor Red
}

Write-Host ""
Write-Host "5. Checking Middleware Registration..." -ForegroundColor Yellow
Write-Host "-" * 80

$appConfig = Get-Content "config\application.rb" -Raw
if ($appConfig -match "AuditMiddleware") {
    Write-Host "✓ AuditMiddleware registered" -ForegroundColor Green
} else {
    Write-Host "✗ AuditMiddleware NOT registered" -ForegroundColor Red
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

if ($missingGems.Count -eq 0 -and $missingFiles.Count -eq 0) {
    Write-Host "✓ All components are in place!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Run: rails db:migrate"
    Write-Host "  2. Run: rails audit:verify"
    Write-Host "  3. Start server and visit: http://localhost:3000/audit_logs"
    Write-Host "  4. Read: AUDIT_TRAIL.md for complete guide"
} else {
    Write-Host "⚠ Some components are missing:" -ForegroundColor Yellow
    if ($missingGems.Count -gt 0) {
        Write-Host "  Missing gems: $($missingGems -join ', ')"
    }
    if ($missingFiles.Count -gt 0) {
        Write-Host "  Missing files:"
        foreach ($file in $missingFiles) {
            Write-Host "    - $file"
        }
    }
}

Write-Host ""
