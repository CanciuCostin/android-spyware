# Quick Start: Tracing & Observability (PowerShell)
# Usage: .\start-with-tracing.ps1

param(
    [switch]$Logs = $false
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message, [string]$Color = "Green")
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $Color
    Write-Host $Message -ForegroundColor $Color
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $Color
}

Write-Host ""
Write-Host "🚀 Starting android-spyware with Tracing & Observability..." -ForegroundColor Cyan
Write-Host ""

# Check Docker
Write-Host "📦 Checking Docker..." -ForegroundColor Blue
$dockerPath = (Get-Command docker -ErrorAction SilentlyContinue).Path
if (-not $dockerPath) {
    Write-Host "❌ Docker not found. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}

try {
    docker ps *> $null
    Write-Host "✅ Docker is running" -ForegroundColor Green
}
catch {
    Write-Host "❌ Docker daemon not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Navigate to docker directory
$dockerDir = Split-Path -Parent $PSCommandPath
Set-Location $dockerDir

Write-Host ""
Write-Host "⏹️  Stopping existing containers..." -ForegroundColor Yellow
docker compose down 2>&1 | Out-Null
Start-Sleep -Seconds 2

Write-Host "🚀 Starting containers with Jaeger tracing..." -ForegroundColor Blue
docker compose up -d

Write-Host "⏳ Waiting for services to start (45 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 45

Write-Host ""
Write-Host "📊 Container Status:" -ForegroundColor Blue
docker compose ps

Write-Host ""
Write-Host "✅ Services started successfully!" -ForegroundColor Green
Write-Host ""

# Display URLs
Write-Header "Service URLs" "Cyan"
Write-Host "  Rails Admin UI:  " -ForegroundColor Gray -NoNewline
Write-Host "http://localhost:9000/admin" -ForegroundColor Green

Write-Host "  Jaeger Traces:   " -ForegroundColor Gray -NoNewline
Write-Host "http://localhost:16686" -ForegroundColor Green

Write-Host "  Database:        " -ForegroundColor Gray -NoNewline
Write-Host "localhost:5432" -ForegroundColor Green

Write-Host "  Metasploit RPC:  " -ForegroundColor Gray -NoNewline
Write-Host "localhost:3333" -ForegroundColor Green

# Display credentials
Write-Header "Default Credentials" "Cyan"
Write-Host "  Email:    " -ForegroundColor Gray -NoNewline
Write-Host "admin@example.com" -ForegroundColor Yellow

Write-Host "  Password: " -ForegroundColor Gray -NoNewline
Write-Host "password" -ForegroundColor Yellow

# Next steps
Write-Header "Next Steps" "Cyan"
Write-Host "  1. Open http://localhost:9000/admin in your browser"
Write-Host "  2. Login with admin credentials"
Write-Host "  3. Generate an APK payload"
Write-Host "  4. Watch traces appear in http://localhost:16686"
Write-Host ""

# Documentation
Write-Host "📚 Documentation: " -ForegroundColor Blue -NoNewline
Write-Host "See docs/TRACING_GUIDE.md for detailed information"
Write-Host ""

# Optional: Tail logs
if ($Logs) {
    Write-Host "📝 Rails Logs (Ctrl+C to stop):" -ForegroundColor Yellow
    docker compose logs -f rails-app
}
else {
    Write-Host "💡 Tip: Run " -ForegroundColor Cyan -NoNewline
    Write-Host ".\start-with-tracing.ps1 -Logs " -ForegroundColor Green -NoNewline
    Write-Host "to see live logs" -ForegroundColor Cyan
}
