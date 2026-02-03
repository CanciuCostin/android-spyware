# ═══════════════════════════════════════════════════════════════
# 🔥 BEAST MODE: Complete Command Testing Automation
# ═══════════════════════════════════════════════════════════════

param(
    [string]$DeviceId = "",
    [string]$RailsHost = "localhost:3001",
    [switch]$SkipDocker,
    [switch]$ParallelMonitoring
)

$ErrorActionPreference = "Continue"
$Script:TestResults = @()
$Script:StartTime = Get-Date

Write-Host "
╔═══════════════════════════════════════════════════════════════╗
║  🔥 BEAST MODE ACTIVATED - Comprehensive Command Testing     ║
╠═══════════════════════════════════════════════════════════════╣
║  Target: $RailsHost                                           ║
║  Device: $(if($DeviceId){"$DeviceId"}else{"Auto-detect"})   ║
║  Started: $($Script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))║
╚═══════════════════════════════════════════════════════════════╝
" -ForegroundColor Cyan

# ═══════════════════════════════════════════════════════════════
# 📋 COMMAND CATALOG (From CommandService.kt + Controllers)
# ═══════════════════════════════════════════════════════════════

$Script:CommandCatalog = @{
    "Device Info" = @(
        @{Command="get_device_info"; Description="Device details"; Controller="SmartphonesController"; AndroidHandler="executeGetDeviceInfo"}
        @{Command="get_wifi_info"; Description="WiFi config"; Controller="SmartphonesController"; AndroidHandler="executeGetWifiInfo"}
        @{Command="get_location"; Description="GPS"; Controller="GeoLocationsController"; AndroidHandler="executeGetLocation"}
    )
    
    "Data Extraction" = @(
        @{Command="get_contacts"; Description="Contacts"; Controller="ContactsController"; AndroidHandler="executeGetContacts"}
        @{Command="get_sms"; Description="SMS messages"; Controller="SmsMessagesController"; AndroidHandler="executeGetSms"}
        @{Command="get_call_logs"; Description="Call history"; Controller="CallLogsController"; AndroidHandler="executeGetCallLogs"}
        @{Command="get_installed_apps"; Description="Apps"; Controller="SmartphonesController"; AndroidHandler="executeGetInstalledApps"}
    )
    
    "Media Capture" = @(
        @{Command="take_picture"; Description="Photo"; Controller="PicturesController"; AndroidHandler="executeStartCamera"}
        @{Command="dump_screen_snap"; Description="Screenshot"; Controller="ScreenshotsController"; AndroidHandler="executeStartScreenRecord"}
    )
}

# Test ADB
Write-Host "`n🔍 Checking ADB device..." -ForegroundColor Yellow
$devices = adb devices | Select-String -Pattern "device$"
if ($devices) {
    $Script:DeviceId = ($devices[0].ToString() -split "\s+")[0]
    Write-Host "✅ Device: $Script:DeviceId" -ForegroundColor Green
} else {
    Write-Host "❌ No device connected!" -ForegroundColor Red
    exit 1
}

# Execute commands
Write-Host "`n🚀 Executing command catalog..." -ForegroundColor Cyan
foreach ($category in $Script:CommandCatalog.Keys) {
    Write-Host "`n📂 $category" -ForegroundColor Magenta
    foreach ($cmd in $Script:CommandCatalog[$category]) {
        Write-Host "  ▶ $($cmd.Command) - $($cmd.Description)" -ForegroundColor Gray
        adb logcat -d SystemCore:V *:S | Select-String $cmd.Command -Context 2
    }
}

Write-Host "`n✅ Test complete!" -ForegroundColor Green
