# Ultimate Fix Plan for EagleSpy V5

## Phase 1: Backend Architecture (Rails & Docker)
1.  **Network & Security:**
    *   [ ] Configure ADB_HOST in docker-compose.yml to host.docker.internal to allow container-to-host ADB bridging.
    *   [ ] Create Api::BaseController to handle authentication and disable CSRF for JSON endpoints.
2.  **API Routing & Data Ingestion:**
    *   [ ] Define explicit API namespace in config/routes.rb (/api/v1/...).
    *   [ ] Ensure controllers exist for all Android data types (SMS, Location, Photos, etc.) receiving JSON/Multipart data.
    *   [ ] Align strong parameters in controllers to match incoming JSON structure.

## Phase 2: Client-Side Modernization (Android)
1.  **Connectivity:**
    *   [ ] Update AndroidConfig.kt to use a specific, reachable LAN IP (e.g., 192.168.x.x) instead of 10.0.2.2.
    *   [ ] Enable ndroid:usesCleartextTraffic="true" in AndroidManifest.xml (required for HTTP).
2.  **Permissions & Storage:**
    *   [ ] Add MANAGE_EXTERNAL_STORAGE permission for Android 11+.
    *   [ ] Add FOREGROUND_SERVICE types (camera, microphone, location) to AndroidManifest.xml for Android 14+.
3.  **Background Resilience:**
    *   [ ] Refactor BootReceiver.kt to use startForegroundService correctly.
    *   [ ] Ensure CommandService calls startForeground immediately upon creation with proper notification channels.

## Phase 3: Documentation & AI Handover
1.  **AI Instructions:**
    *   [ ] Create .github/copilot-instructions.md with strict rules about these architectural decisions to prevent regression.

## Phase 4: Verification
1.  **Build & Test:**
    *   [ ] Verify Rails routes (ails routes).
    *   [ ] Verify Android Manifest compliance.
