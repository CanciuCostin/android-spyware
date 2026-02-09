# ADR-002: Use ActionCable for Real-Time Communication

**Date:** 2020-01-15  
**Status:** Accepted

## Context

EagleSpy requires persistent, bidirectional communication between the Rails
server and Android devices for command dispatch, response streaming, location
updates, and keylog broadcasting. Polling via REST introduces latency and
wastes bandwidth on mobile networks.

Alternatives considered:
- **Socket.IO (Node.js sidecar)** — mature but adds operational complexity of
  a second runtime.
- **Pusher / Firebase Cloud Messaging** — third-party dependency; data leaves
  the operator's network.
- **gRPC streaming** — efficient but harder to integrate with a Rails monolith
  and browser clients.

## Decision

Use **ActionCable**, the WebSocket framework built into Rails, backed by a
**Redis** pub/sub adapter.

Channels implemented:
| Channel            | Purpose                                    |
|--------------------|--------------------------------------------|
| `CommandChannel`   | C2 command dispatch and device responses    |
| `SignalingChannel`  | WebRTC SDP/ICE signaling                   |
| `StreamingChannel` | Live camera/microphone streaming metadata  |
| `LocationChannel`  | Real-time GPS updates                      |
| `KeylogChannel`    | Keylog entry broadcasting                  |
| `StatisticsChannel`| Device statistics push                     |

## Consequences

### Positive
- Zero additional infrastructure — ActionCable ships with Rails.
- Unified auth model; Devise session cookies work for admin channels.
- Device token auth integrates naturally via `ApplicationCable::Connection`.
- Redis adapter allows horizontal scaling across multiple Puma workers.

### Negative
- Each WebSocket connection consumes a Puma thread; thread pool must be sized
  accordingly.
- Redis becomes a single point of failure for real-time features; requires
  Redis HA in production.
- ActionCable's JavaScript client is Rails-specific; Android client needed a
  custom implementation.
