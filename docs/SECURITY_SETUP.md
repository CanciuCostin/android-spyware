# Security Setup Guide

This guide explains how to secure your EagleSpy V5 installation before deployment.

## ⚠️ Critical Warning

Never deploy this application with default credentials! The default `.env` configuration contains placeholders like `CHANGE_ME_IN_PRODUCTION`.

## 1. Credentials Generation

We have provided a PowerShell script to automatically generate strong credentials for all services.

Run this command in PowerShell:
```powershell
./scripts/generate_credentials.ps1
```

Or manually generate them using these commands:

### Database Password
```bash
openssl rand -base64 24
```

### Rails Secret Key Base
```bash
rails secret
# OR
ruby -rsecurerandom -e "puts SecureRandom.hex(64)"
```

### Device Authentication Token
```bash
openssl rand -hex 32
```

## 2. Environment Configuration

Edit your `.env` file and ensure ALL the following variables are set with strong, unique values:

- `POSTGRES_PASSWORD`
- `SECRET_KEY_BASE`
- `TURN_PASSWORD`
- `MSF_PASS`
- `ADMIN_PASSWORD`
- `DEVICE_AUTH_TOKEN`
- `REDIS_PASSWORD`

## 3. Docker Security

### Docker Socket
Do NOT mount `/var/run/docker.sock` in the docker-compose file unless you fully understand the risks (container escape). The V5 update has removed this default mount for security.

### Network Isolation
The application runs in a custom bridge network (`default`). Ensure your firewall blocks external access to internal ports:
- 5432 (Postgres)
- 6379 (Redis)
- 2222 (MSF RPC)

Only port `80` (or `443`) and `3478` (TURN) should be exposed to the internet.

## 4. SSL/TLS Enforcement

In production, you MUST use SSL/TLS to protect:
1. Admin login credentials
2. Device authentication tokens
3. Keylog data in transit
4. Live video/audio streams

Set `USE_SSL=true` in your `.env` file and configure a reverse proxy (Nginx/Traefik) with valid certificates.

## 5. Rate Limiting

Rate limiting is enabled by default via `Rack::Attack`. It uses Redis to track request rates across multiple processes.

Default limits:
- Login attempts: 5 per minute per IP
- API requests: 300 per 5 minutes per IP

## 6. Audit Logs

Check `log/production.log` and `log/security.log` regularly for suspicious activity.
