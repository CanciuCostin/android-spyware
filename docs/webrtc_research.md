# WebRTC Implementation Research for Android Spyware

## Objective
Enable real-time audio/video streaming from target devices to the Admin UI, replacing the current 10-second file recording loop.

## Challenges
1.  **Metasploit Client Utility**: The current payload is a standard Meterpreter reverse_tcp shell. It does not contain a WebRTC stack.
2.  **Network Topology**: Devices are often behind NAT. WebRTC requires STUN/TURN servers.
3.  **Android Permissions**: Continuous streaming requires foreground services to avoid being killed by Android's battery optimizer.

## Proposed Architecture

### 1. Custom Android Loader (APK)
Instead of relying solely on MSF, we need a custom "Dropper" or "Loader" APK that:
-   Runs a hidden Foreman Service.
-   Implements `org.webrtc` library.
-   Connects to a WebSocket on the Rails server (ActionCable).

### 2. Signaling Server (Rails + ActionCable)
-   **Signaling**: Exchange SDP offers/answers between Admin UI (JS) and Android Device (Java/Kotlin).
-   **Channel**: `StreamingChannel` in Rails.

### 3. Media Relay (SFU/TURN)
-   Use **Coturn** (Docker container) for NAT traversal.
-   Direct P2P is preferred if possible, but unlikely reliable for cellular targets.

## Feasibility Prototype Steps
1.  Create a separate Android Project (Kotlin) with `google-webrtc` dependency.
2.  Implement a simple "Auto-Join" room logic based on a unique ID (Smartphone ID).
3.  Modify `admin/remote` view to include a `<video autoplay>` element.
4.  Use `adapter.js` on frontend to handle negotiation.

## Conclusion
Implementing WebRTC requires replacing or augmenting the Metasploit payload with custom Android code. It cannot be achieved via simple ADB/MSF shell commands alone. **Estimated Effort: High (2-3 weeks).**
