# EagleSpy V5 — Complete Feature List

## Feature Status Legend

| Status | Meaning |
|--------|---------|
| ✅ | Implemented and tested |
| 🔧 | Implemented, needs testing |
| 📋 | Planned / documented |

---

## 1. Surveillance Features

| Feature | Status | Endpoint / Path |
|---------|--------|-----------------|
| Live Camera Streaming (WebRTC) | ✅ | `/admin/live_streaming`, WebRTC signaling |
| Live Location Tracking | ✅ | `/admin/live_location` |
| Keylogger | ✅ | `POST /api/keylogger`, `/admin/keylogs` |
| Notification Capture | ✅ | `POST /api/notifications` |
| Clipboard Monitoring | ✅ | `POST /api/clipboard` |
| Take Photo (Front/Rear) | ✅ | `POST /smartphones/take_picture` |
| Screenshot Capture | ✅ | `GET /screenshots/dump_screen_snap` |
| Screen Recording | ✅ | `POST /screenshots/screen_record` |
| Microphone Recording | ✅ | `POST /recordings/microphone_rec` |
| Ambient Recording | ✅ | `POST /smartphones/ambient_record` |

## 2. Data Collection

| Feature | Status | Endpoint |
|---------|--------|----------|
| SMS Dump | ✅ | `POST /api/sms` |
| Contact Dump | ✅ | `POST /api/contacts` |
| Call Log Dump | ✅ | `POST /api/calls` |
| Photo Upload | ✅ | `POST /api/photos` |
| Audio Upload | ✅ | `POST /api/audio` |
| App Usage Tracking | ✅ | `POST /api/app_usage` |
| Browser History | ✅ | `POST /api/browser_history` |
| File Browser | ✅ | `GET/POST /api/smartphones/:id/files` |
| WhatsApp Database Extraction | ✅ | `/messaging_apps_dumps/*` |

## 3. Device Control

| Feature | Status | Endpoint |
|---------|--------|----------|
| Shell Command Execution | ✅ | `POST /smartphones/run_shell_command` |
| List Installed Apps | ✅ | `POST /smartphones/list_apps` |
| Install App | ✅ | `POST /smartphones/install_app` |
| Uninstall App | ✅ | `POST /smartphones/uninstall_app` |
| Open App | ✅ | `POST /smartphones/open_app` |
| Hide/Show App Icon | ✅ | `GET /smartphones/hide_app`, `/show_app` |
| Toggle WiFi | ✅ | `POST /smartphones/toggle_wifi` |
| Wake Screen | ✅ | `POST /smartphones/wake_lock` |
| Set Audio Mode | ✅ | `POST /smartphones/set_audio_mode` |
| Send SMS | ✅ | `POST /sms_messages/send_sms` |
| Device Info Dump | ✅ | `POST /smartphones/dump_device_info` |
| WiFi Info Dump | ✅ | `POST /smartphones/dump_wifi_info` |
| Get Accounts | ✅ | `POST /smartphones/get_accounts` |

## 4. Security & Detection

| Feature | Status | Endpoint |
|---------|--------|----------|
| GPS Spoofing Detection | 🔧 | `GET /api/devices/:id/security/gps_analysis` |
| Media Integrity Analysis | 🔧 | `GET /api/devices/:id/security/media_analysis` |
| Tamper Detection | 🔧 | `GET /api/devices/:id/security/tamper_status` |
| Voice Deepfake Indicators | 🔧 | Via `DeepfakeDetectionService` |
| App Signature Verification | 🔧 | `IntegrityChecker.kt` (client-side) |
| Emulator Detection | ✅ | `EnvironmentCheck.kt` / `IntegrityChecker.kt` |
| Root Detection | ✅ | `EnvironmentCheck.kt` / `IntegrityChecker.kt` |
| Debug Detection | ✅ | `EnvironmentCheck.kt` / `IntegrityChecker.kt` |
| Mock Location Detection | 🔧 | `IntegrityChecker.kt` |

## 5. Geofencing

| Feature | Status | Endpoint |
|---------|--------|----------|
| Create Geofence (circle/polygon) | ✅ | `POST /api/devices/:id/geofences` |
| Geofence Entry/Exit Alerts | ✅ | Real-time via ActionCable |
| Location History | ✅ | `GET /api/devices/:id/location_history` |
| Location Heatmap | ✅ | `GET /api/devices/:id/location_heatmap` |
| Geofence Events Log | ✅ | `GET /api/devices/:id/geofence_events` |

## 6. Scheduling & Automation

| Feature | Status | Endpoint |
|---------|--------|----------|
| Scheduled Commands | ✅ | `POST /api/devices/:id/scheduled_commands` |
| Command Toggle (enable/disable) | ✅ | `POST /api/devices/:id/scheduled_commands/:id/toggle` |
| Execution History | ✅ | `GET /api/devices/:id/scheduled_commands/:id/executions` |

## 7. AI & Analytics

| Feature | Status | Endpoint |
|---------|--------|----------|
| AI Chat Interface | ✅ | `/admin/ai_chat` |
| AI Behavior Report | ✅ | `/admin/ai_analysis` |
| AI Daily Summary | ✅ | `/admin/ai_analysis` |
| AI Data Analysis | ✅ | `/admin/ai_analysis` |
| Keylog Analytics | ✅ | `GET /api/devices/:id/keylog_analytics` |
| App Usage Analytics | ✅ | `GET /api/devices/:id/keylog_analytics/app_usage` |
| Activity Timeline | ✅ | `GET /api/devices/:id/keylog_analytics/activity_timeline` |
| Device Statistics | ✅ | `GET /devices/:id/statistics` |

## 8. Fleet Management

| Feature | Status | Endpoint |
|---------|--------|----------|
| Device Groups | ✅ | `/device_groups` |
| Bulk Commands | ✅ | `POST /device_groups/:id/bulk_command` |
| Device Tags | ✅ | `/apk_installations/:id/tags` |
| APK Installation Management | ✅ | `/apk_installations` |
| App Control Panel | ✅ | `/apk_installations/:id/apps` |

## 9. Compliance & Privacy

| Feature | Status | Endpoint |
|---------|--------|----------|
| Data Erasure Request (GDPR) | ✅ | `POST /api/devices/:id/erasure_request` |
| Data Export | ✅ | `GET /api/devices/:id/data_export` |
| Retention Policy | ✅ | `GET/PUT /api/devices/:id/retention_policy` |
| Privacy Policy Generator | ✅ | `GET /api/devices/:id/privacy_policy` |
| Consent Management | ✅ | `/apk_installations/:id/consents` |
| Audit Trail | ✅ | `/audit_logs` |

## 10. Notifications & Alerts

| Feature | Status | Endpoint |
|---------|--------|----------|
| Alert Rules | ✅ | `/alert_rules` |
| Alert Acknowledgment | ✅ | `POST /alerts/:id/acknowledge` |
| Notification Channels | ✅ | `/notification_channels` |
| Channel Test | ✅ | `POST /notification_channels/:id/test` |

## 11. Infrastructure & Observability

| Feature | Status | Endpoint |
|---------|--------|----------|
| Health Checks | ✅ | `/health`, `/health/ready`, `/health/live`, `/health/startup` |
| Prometheus Metrics | ✅ | `/metrics` |
| Error Tracking | ✅ | `/api/errors` |
| Telemetry (devices, queues) | ✅ | `/api/v1/telemetry/*` |
| Connection Monitoring | ✅ | `/api/v1/connections` |
| Circuit Breakers | ✅ | `/api/v1/circuit_breakers` |
| Offline Command Queue | ✅ | `/api/v1/offline_queue/:device_id` |
| Chunked File Uploads | ✅ | `/file_transfers/upload_chunk` |
| User Preferences | ✅ | `/api/preferences` |
| Sidekiq Dashboard | ✅ | `/admin/sidekiq_dashboard` |

## 12. WebRTC & Streaming

| Feature | Status | Endpoint |
|---------|--------|----------|
| TURN Credentials | ✅ | `GET /webrtc/turn_credentials` |
| WebRTC Signaling | ✅ | `POST /webrtc/signal` |
| Start WebRTC Stream | ✅ | `POST /smartphones/start_webrtc_stream` |

---

## API Endpoint Reference

### Authentication

All API endpoints require one of:
- **HMAC Signature**: `X-Device-ID` + `X-Device-Signature` + `X-Device-Timestamp` headers
- **Token**: `X-Device-Token` header or `token` parameter

### Base URL

```
http://<server>:3000/api/
```

### Response Format

All API responses are JSON:
```json
{
  "status": "ok|error",
  "data": { ... },
  "message": "Error description (on failure)"
}
```

---

## Configuration Reference

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANDROIDSPYWARE_DATABASE_HOST` | Yes | `localhost` | PostgreSQL host |
| `ANDROIDSPYWARE_DATABASE_PORT` | No | `5432` | PostgreSQL port |
| `ADB_HOST` | Yes | `localhost` | ADB server host |
| `RAILS_HOST` | Yes | `127.0.0.1` | Rails bind address |
| `DEVICE_AUTH_TOKEN` | Yes | — | Device API authentication token |
| `DEVICE_SIGNATURE_SKEW_SECONDS` | No | `300` | Allowable clock skew for HMAC auth |
| `MAX_UPLOAD_BYTES` | No | `10485760` | Maximum upload payload size (10MB) |
| `EXPECTED_APP_SIGNATURE` | No | — | Expected APK signing certificate hash |
| `REDIS_URL` | No | `redis://localhost:6379` | Redis connection URL |
| `SECRET_KEY_BASE` | Yes | — | Rails secret key |
| `OPENAI_API_KEY` | No | — | OpenAI API key for AI features |
| `TURN_SERVER_URL` | No | — | TURN server URL for WebRTC |
| `TURN_USERNAME` | No | — | TURN server username |
| `TURN_PASSWORD` | No | — | TURN server password |

### Docker Compose Files

| File | Purpose |
|------|---------|
| `docker-compose.blue.yml` | Blue deployment configuration |
| `docker-compose.green.yml` | Green deployment configuration |

### Key Configuration Files

| File | Purpose |
|------|---------|
| `config/routes.rb` | All application routes |
| `config/database.yml` | Database configuration |
| `config/cable.yml` | ActionCable (WebSocket) configuration |
| `config/webpacker.yml` | Frontend asset bundling |
| `config/puma.rb` | Puma web server configuration |
| `.env` | Environment variables (copy from `.env.example`) |
