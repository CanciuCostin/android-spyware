# EagleSpy V5 - Remove Firewall Rules Script
# Премахва всички firewall правила създадени от configure-firewall.ps1

Write-Host "🔥 Премахване на EagleSpy V5 firewall правила..." -ForegroundColor Cyan

# Проверка за admin права
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ ГРЕШКА: Скриптът изисква Administrator права!" -ForegroundColor Red
    Write-Host "   Стартирай PowerShell като Administrator и опитай отново." -ForegroundColor Yellow
    exit 1
}

# Списък с правилата за премахване
$rules = @(
    "EagleSpy Rails Server",
    "EagleSpy Metasploit Handler",
    "EagleSpy Frontend Dev",
    "EagleSpy PostgreSQL",
    "EagleSpy Redis",
    "EagleSpy TURN Server TCP",
    "EagleSpy TURN Server UDP",
    "EagleSpy Jaeger UI",
    "EagleSpy Jaeger Collector"
)

Write-Host "`n📋 Премахване на правила..." -ForegroundColor Cyan

foreach ($ruleName in $rules) {
    try {
        $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        if ($rule) {
            Remove-NetFirewallRule -DisplayName $ruleName
            Write-Host "✅ Премахнато: $ruleName" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️  Не е намерено: $ruleName" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Грешка при премахване на '$ruleName': $_" -ForegroundColor Red
    }
}

Write-Host "`n✅ Всички EagleSpy firewall правила премахнати!" -ForegroundColor Green
Write-Host ""
