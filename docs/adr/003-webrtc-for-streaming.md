# ADR-003: Use WebRTC for Live Streaming

**Date:** 2021-06-01  
**Status:** Accepted

## Context

EagleSpy needs low-latency live video and audio streaming from Android devices
to the admin browser dashboard. Traditional HTTP-based streaming (HLS/DASH)
introduces 5–30 seconds of latency, which is unacceptable for real-time
surveillance.

Alternatives considered:
- **HLS / DASH** — high latency; requires transcoding on the device.
- **RTMP → media server** — adds a dedicated media server (Wowza/Nginx-RTMP);
  lower latency but still 2–5 seconds.
- **Raw WebSocket binary frames** — low-level; would need custom codec
  handling on both ends.

## Decision

Use **WebRTC** for peer-to-peer audio/video streaming between the Android
device and the admin browser.

Architecture:
```
Android Device                Rails Server               Admin Browser
     │                            │                            │
     │── subscribe SignalingChannel ──│                        │
     │                            │── subscribe SignalingChannel ──│
     │                            │                            │
     │                            │◄── start_stream_request ───│
     │◄── start_stream_request ───│                            │
     │                            │                            │
     │── SDP offer ──────────────►│── relay to admin ─────────►│
     │                            │◄── SDP answer ─────────────│
     │◄── relay to device ────────│                            │
     │                            │                            │
     │◄─── ICE candidates ───────►│◄──── ICE candidates ──────►│
     │                            │                            │
     │════════ P2P media stream (bypasses server) ════════════►│
```

Supporting infrastructure:
- **coturn TURN server** — NAT traversal relay for networks where direct P2P
  fails. Deployed as a Docker container.
- **SignalingChannel** — ActionCable channel that relays SDP offers/answers and
  ICE candidates between peers. The server never touches media data.

## Consequences

### Positive
- Sub-second latency; media travels peer-to-peer once ICE completes.
- Server bandwidth is minimal — only signaling messages are relayed.
- Browser-native; no plugins needed on the admin side.
- TURN server ensures connectivity even behind symmetric NATs.

### Negative
- WebRTC is complex; debugging ICE failures requires understanding of NAT
  traversal, STUN, and TURN.
- Android WebRTC SDK adds ~15 MB to the APK.
- TURN server must be publicly reachable; adds an attack surface.
- Only one admin viewer per stream session (no multicast without an SFU).
