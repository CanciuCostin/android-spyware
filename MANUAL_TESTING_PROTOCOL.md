# 🔥 BEAST MODE - MANUAL TESTING PROTOCOL
**Generated:** 2026-02-03 15:09:12

## ⚠️ CRITICAL BLOCKERS
1. **No ADB device** → Connect device/emulator + enable USB debugging
2. **Rails server down** → Fix Docker port 3000→3001 OR install gems locally

## 📋 24 COMMANDS CATALOGED
See test-all-commands.ps1 for full catalog organized by category.

## �� MANUAL TESTING WORKFLOW

### Setup 3 Terminals
**Terminal 1:** Rails logs
```powershell
Get-Content "e:\EagleSpy V5\log\development.log" -Wait -Tail 50 | Select-String "CommandChannel"
```

**Terminal 2:** Android logcat
```powershell
adb logcat SystemCore:V *:S
```

**Terminal 3:** Jaeger tracing
```powershell
Start-Process "http://localhost:16686"
```

### Execute via Admin Panel
1. Open: http://localhost:3001/admin/remote
2. Select device
3. Click command button
4. Watch logs in parallel (Rails broadcast → ADB receive → Response)

### Results Matrix Template
| Command | Rails ✅ | ADB ✅ | Time | Response | Status |
|---------|---------|--------|------|----------|--------|
| get_device_info | Timestamp | Timestamp | 0.5s | JSON | ✅ PASS |

## 🚀 AUTOMATED SCRIPT (When Ready)
```powershell
cd "e:\EagleSpy V5"
.\test-all-commands.ps1 -ParallelMonitoring
```

**Features:**
- Auto-detects device
- Tests all 24 commands
- Captures logs per command
- Generates HTML report + CSV

## ✅ SUCCESS CRITERIA
**Minimum:** 3 device info commands + keylogger work
**Comprehensive:** 20/24 commands pass (<5s timeout)
**Production:** 48h stability + multi-device

---
**NEXT:** Resolve blockers → run script → review results matrix
