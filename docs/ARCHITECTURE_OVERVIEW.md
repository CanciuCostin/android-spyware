# EagleSpy V5 — Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ADMIN BROWSER (UI)                           │
│   ActiveAdmin Dashboard · WebRTC Viewer · AI Chat · Security Panel  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ HTTPS / WSS
┌──────────────────────────────▼──────────────────────────────────────┐
│                     RAILS APPLICATION SERVER                        │
│  ┌──────────┐  ┌───────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │ ActiveAd │  │  REST API │  │ ActionCab │  │   GraphQL API    │  │
│  │ min UI   │  │ Controlle │  │ le (WS)   │  │   /graphql       │  │
│  └────┬─────┘  └─────┬─────┘  └─────┬─────┘  └────────┬─────────┘  │
│       │              │              │                  │            │
│  ┌────▼──────────────▼──────────────▼──────────────────▼─────────┐  │
│  │                     SERVICE LAYER                              │  │
│  │  DeepfakeDetection · GpsSpoofing · Geofence · Keylog · ADB   │  │
│  │  AlertService · AuditService · CommandScheduler · FileUpload  │  │
│  │  MetricsService · CacheService · DataExport · StorageService  │  │
│  └──────────┬───────────────┬───────────────┬────────────────────┘  │
│             │               │               │                      │
│  ┌──────────▼──┐  ┌────────▼────┐  ┌───────▼────────┐             │
│  │ PostgreSQL  │  │   Redis     │  │  File Storage  │             │
│  │ Database    │  │   Cache/PubS│  │  (local/S3)    │             │
│  └─────────────┘  └─────────────┘  └────────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │ REST/WS            │ ADB Bridge         │ WebRTC (TURN)
┌────────┴────────┐  ┌───────┴───────┐  ┌────────┴────────────────┐
│ ANDROID CLIENT  │  │  METASPLOIT   │  │     TURN SERVER         │
│ (Spyware APK)   │  │  (msfrpcd)    │  │   (coturn/STUN)        │
└─────────────────┘  └───────────────┘  └─────────────────────────┘
```

## Component Interactions

### 1. Android Client → Rails Server

The Android client communicates with the server via:

- **REST API** (`/api/*`): Location uploads, SMS dumps, keylog data, media uploads, heartbeats
- **WebSocket** (ActionCable): Real-time command delivery, status updates, live streaming signals
- **WebRTC**: Peer-to-peer live camera/audio streaming (signaled through ActionCable)

### 2. Rails Server → Admin UI

- **ActiveAdmin**: Server-rendered dashboard with device management, data views, AI analysis
- **ActionCable**: Real-time updates pushed to admin browser (device status, geofence alerts, keylogs)
- **Turbolinks**: SPA-like navigation within admin interface

### 3. Rails Server → External Services

- **Metasploit (msfrpcd)**: Payload generation, exploit execution via MsfRpcService
- **Redis**: Caching (device states, rate limits), pub/sub (ActionCable backend), Sidekiq job queue
- **PostgreSQL**: Primary data store for all device data, configurations, and security events
- **TURN Server**: WebRTC relay for NAT traversal during live streaming

## Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Backend Framework** | Ruby on Rails | ~> 6.0.2 |
| **Language** | Ruby | 2.6.6 |
| **Database** | PostgreSQL | 12+ |
| **Cache/Queue** | Redis | 6+ |
| **Web Server** | Puma | 4.x |
| **Admin UI** | ActiveAdmin | 2.x |
| **Authentication** | Devise | 4.x |
| **Frontend Bundler** | Webpacker | 4.x |
| **JS Libraries** | jQuery, Xterm.js, Chart.js | Various |
| **CSS Framework** | Bootstrap | 4.x |
| **Real-time** | ActionCable (WebSocket) | Rails built-in |
| **Streaming** | WebRTC | Browser native |
| **Android Client** | Kotlin | 1.5+ |
| **Testing** | RSpec, Capybara | 3.x |
| **Containerization** | Docker, Docker Compose | 20+ |
| **Observability** | OpenTelemetry, Prometheus | Latest |

## Data Flow

### Command Execution Flow

```
Admin UI → POST /smartphones/:action
         → SmartphonesController
         → AdbCommandService / DeviceCommandService
         → ADB Bridge → Android Device
         → Response → ActionCable broadcast → Admin UI
```

### Data Ingestion Flow

```
Android Client → POST /api/{sms|contacts|photos|...}
               → Api::*Controller
               → InputValidator (sanitization)
               → ActiveRecord (PostgreSQL)
               → ActionCable broadcast (real-time UI update)
```

### Security Analysis Flow

```
Android Client → IntegrityChecker.runFullCheck()
               → GET /api/devices/:id/security/tamper_status
               → SecurityAnalysisController
               → DeepfakeDetectionService
               → SecurityEvent (recorded to DB)
               → Admin Security Dashboard (real-time)
```

### Live Streaming Flow

```
Admin UI → Start Stream request
         → SignalingChannel (ActionCable)
         → Android Client receives WebRTC offer
         → ICE candidate exchange via ActionCable
         → TURN server for NAT traversal
         → Peer-to-peer media stream → Admin viewer
```

## Security Model

### Authentication Layers

1. **Admin UI**: Devise-based authentication with session management
2. **API (Device)**: HMAC signature verification (`X-Device-Signature` + `X-Device-Timestamp`) or token-based (`X-Device-Token`)
3. **WebSocket**: Device ID verification on ActionCable subscription

### Data Protection

- **Input Validation**: `InputValidator` service sanitizes all incoming data
- **CSRF Protection**: Rails built-in for admin; skipped for API (token auth instead)
- **Rate Limiting**: `Rack::Attack` with configurable thresholds
- **Payload Size Limits**: `MAX_UPLOAD_BYTES` enforcement on all API uploads
- **Device ID Sanitization**: Regex whitelist preventing path traversal

### Anti-Tamper (Android Client)

- APK signature verification at runtime
- Debugger and TracerPid detection
- Root/Magisk detection
- Emulator environment detection
- Mock location provider detection

### Security Event Monitoring

- All security analysis results stored in `security_events` table
- Real-time dashboard with severity-based filtering
- GPS spoofing alerts with impossible travel detection
- Media integrity analysis for deepfake indicators

## Directory Structure

```
EagleSpy V5/
├── app/
│   ├── admin/           # ActiveAdmin page registrations
│   ├── channels/        # ActionCable channels (command, signaling, geofence)
│   ├── controllers/     # Rails controllers
│   │   ├── api/         # REST API controllers for Android client
│   │   └── concerns/    # Shared controller logic
│   ├── graphql/         # GraphQL schema and resolvers
│   ├── models/          # ActiveRecord models
│   ├── services/        # Business logic services
│   │   ├── concerns/    # Shared service modules
│   │   ├── notifiers/   # Notification delivery (Slack, email, webhook)
│   │   └── storage/     # File storage adapters (local, S3)
│   └── views/           # ERB templates and partials
├── android-client/      # Android spyware APK source (Kotlin)
├── config/              # Rails configuration, routes, initializers
├── db/                  # Migrations and schema
├── docker/              # Docker configurations
├── docs/                # Project documentation
├── frontend/            # Webpacker frontend assets
├── lib/                 # Library code, Rake tasks
├── spec/                # RSpec test suite
└── scripts/             # Utility scripts
```

## Deployment

### Docker Compose Services

| Service | Image | Purpose |
|---------|-------|---------|
| `web` | Custom Rails | Main application server |
| `db` | PostgreSQL | Primary database |
| `redis` | Redis | Cache, pub/sub, job queue |
| `msf` | Metasploit | Payload generation |
| `turn` | coturn | WebRTC TURN server |

### Blue-Green Deployment

The project supports blue-green deployments via separate compose files:
- `docker-compose.blue.yml`
- `docker-compose.green.yml`
