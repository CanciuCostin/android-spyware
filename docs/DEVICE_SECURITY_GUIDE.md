# Device Security Guide

Enterprise device hardening and compliance features for corporate MDM.

## Overview

The Device Security system provides compliance checking, integrity verification, and security policy enforcement for managed Android devices. These are standard MDM features used by enterprise IT departments.

## Components

### DeviceSecurityManager

Located at: `android-client/.../utils/DeviceSecurityManager.kt`

Handles:
- **Device compliance checking** — encryption, PIN/pattern lock, OS version, security patch level
- **Security policy enforcement** — enforce corporate security policies remotely
- **Battery optimization management** — request exemption for MDM service persistence
- **Notification channel management** — create required Android notification channels
- **Boot receiver** — restart MDM services after device reboot

### DeviceIntegrityChecker

Located at: `android-client/.../utils/DeviceIntegrityChecker.kt`

Handles:
- **App integrity verification** — SHA-256 signature hash validation
- **OS integrity check** — leverages existing `IntegrityChecker` (root, debug, emulator, mock location detection)
- **Compliance score calculation** — 0-100 score based on security posture
- **Server reporting** — sends security posture to the server

## Compliance Checks

| Check | Weight | Description |
|-------|--------|-------------|
| App signature valid | -30 if invalid | Verifies APK signing certificate |
| Root detected | -20 if true | Checks for su binary, Magisk, root management apps |
| Debug detected | -15 if true | Debugger attached, TracerPid, debug build |
| Emulator detected | -10 if true | Build properties, QEMU files, goldfish driver |
| Mock location | -10 if true | Mock provider, spoofing apps |
| Device encrypted | -15 if false | Full-disk or file-based encryption |
| PIN/lock set | -10 if false | Screen lock with PIN, pattern, or biometric |
| Security patch recent | -5 if stale | Within 6 months of current date |
| API level ≥ 26 | -5 if below | Android 8.0 (Oreo) minimum |

### Risk Levels

| Score | Risk Level |
|-------|-----------|
| 90-100 | Low |
| 70-89 | Medium |
| 50-69 | High |
| 0-49 | Critical |

## Usage

### Checking Compliance (Android)

```kotlin
val compliance = DeviceSecurityManager.checkCompliance(context)
if (!compliance.isCompliant) {
    Log.w("MDM", "Device not compliant: ${compliance.details}")
}
```

### Running Full Integrity Assessment

```kotlin
val posture = DeviceIntegrityChecker.assessIntegrity(context)
Log.d("MDM", "Score: ${posture.complianceScore}, Risk: ${posture.riskLevel}")
```

### Reporting Posture to Server

```kotlin
// In a coroutine scope:
val success = DeviceIntegrityChecker.reportPostureToServer(context)
```

### Enforcing Security Policy

```kotlin
val policy = JSONObject().apply {
    put("require_encryption", true)
    put("require_screen_lock", true)
    put("min_api_level", 26)
    put("require_battery_exempt", true)
}
DeviceSecurityManager.enforceSecurityPolicy(context, policy)
```

### Boot Persistence

The `BootCompletedReceiver` automatically restarts MDM services after device reboot. Register in `AndroidManifest.xml`:

```xml
<receiver
    android:name=".utils.BootCompletedReceiver"
    android:enabled="true"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.LOCKED_BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

## Server-Side Integration

The security posture is reported to:

```
POST /api/devices/:id/security/posture
```

This integrates with the existing Security Analysis controller (`Api::SecurityAnalysisController`).

## Notification Channels

The following notification channels are created automatically:

| Channel ID | Purpose | Importance |
|-----------|---------|------------|
| `mdm_service` | Background MDM services | MIN |
| `screen_mirror_channel` | Active screen mirroring | LOW |
| `security_alerts` | Security & compliance alerts | HIGH |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Services don't restart after reboot | Verify `BootCompletedReceiver` is registered in manifest |
| Battery kills services | Request battery optimization exemption |
| Low compliance score | Check which factors contribute; address highest-weight items first |
| Signature validation fails | Ensure the APK is signed with the expected certificate |
