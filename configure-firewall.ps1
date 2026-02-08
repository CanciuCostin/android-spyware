# EagleSpy V5 - Firewall Configuration Script
# Автоматично отваря необходимите портове в Windows Firewall

Write-Host "🔥 Конфигуриране на Windows Firewall за EagleSpy V5..." -ForegroundColor Cyan

# Проверка за admin права
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ ГРЕШКА: Скриптът изисква Administrator права!" -ForegroundColor Red
    Write-Host "   Стартирай PowerShell като Administrator и опитай отново." -ForegroundColor Yellow
    exit 1
}

# Функция за добавяне на firewall правило
function Add-FirewallRule {
    param(
        [string]$Name,
        [string]$Port,
        [string]$Protocol = "TCP",
        [string]$Direction = "Inbound"
    )
    
    try {
        # Проверка дали правилото вече съществува
        $existingRule = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue
        
        if ($existingRule) {
            Write-Host "⚠️  Правило '$Name' вече съществува. Изтриване..." -ForegroundColor Yellow
            Remove-NetFirewallRule -DisplayName $Name
        }
        
        # Добавяне на новото правило
        New-NetFirewallRule `
            -DisplayName $Name `
            -Direction $Direction `
            -LocalPort $Port `
            -Protocol $Protocol `
            -Action Allow `
            -Profile Any `
            -Enabled True | Out-Null
            
        Write-Host "✅ Добавено: $Name (Port $Port/$Protocol)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Грешка при добавяне на '$Name': $_" -ForegroundColor Red
    }
}

Write-Host "`n📋 Добавяне на firewall правила..." -ForegroundColor Cyan

# Rails Application
Add-FirewallRule -Name "EagleSpy Rails Server" -Port 8080 -Protocol TCP

# Metasploit Reverse Handler
Add-FirewallRule -Name "EagleSpy Metasploit Handler" -Port 4444 -Protocol TCP

# Frontend Dev Server
Add-FirewallRule -Name "EagleSpy Frontend Dev" -Port 5173 -Protocol TCP

# PostgreSQL Database
Add-FirewallRule -Name "EagleSpy PostgreSQL" -Port 5432 -Protocol TCP

# Redis
Add-FirewallRule -Name "EagleSpy Redis" -Port 6379 -Protocol TCP

# CoTURN Server (TCP)
Add-FirewallRule -Name "EagleSpy TURN Server TCP" -Port 3490 -Protocol TCP

# CoTURN Server (UDP)
Add-FirewallRule -Name "EagleSpy TURN Server UDP" -Port 3490 -Protocol UDP

# Jaeger UI
Add-FirewallRule -Name "EagleSpy Jaeger UI" -Port 16686 -Protocol TCP

# Jaeger Collector (UDP)
Add-FirewallRule -Name "EagleSpy Jaeger Collector" -Port 6831 -Protocol UDP

Write-Host "`n✅ Firewall конфигуриран успешно!" -ForegroundColor Green
Write-Host "`n📊 Отворени портове:" -ForegroundColor Cyan
Write-Host "   - 8080   : Rails Application (HTTP)" -ForegroundColor White
Write-Host "   - 4444   : Metasploit Reverse Handler" -ForegroundColor White
Write-Host "   - 5173   : Frontend Development Server" -ForegroundColor White
Write-Host "   - 5432   : PostgreSQL Database" -ForegroundColor White
Write-Host "   - 6379   : Redis Cache/ActionCable" -ForegroundColor White
Write-Host "   - 3490   : CoTURN Server (TCP/UDP)" -ForegroundColor White
Write-Host "   - 16686  : Jaeger Tracing UI" -ForegroundColor White
Write-Host "   - 6831   : Jaeger Collector (UDP)" -ForegroundColor White

Write-Host "`n🌐 Network Info:" -ForegroundColor Cyan
$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*"} | Select-Object IPAddress, InterfaceAlias
foreach ($ip in $ipAddresses) {
    Write-Host "   - $($ip.IPAddress) ($($ip.InterfaceAlias))" -ForegroundColor White
}

Write-Host "`n💡 За да премахнеш правилата, използвай: .\remove-firewall-rules.ps1" -ForegroundColor Yellow
Write-Host ""
