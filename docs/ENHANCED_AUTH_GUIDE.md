# Enhanced Authentication Guide

## Overview

EagleSpy V5 includes enhanced authentication with three modules:
- **Two-Factor Authentication (2FA)** — TOTP-based, per-admin enforcement
- **Session Management** — Configurable timeout, concurrent session limits
- **API Key Management** — Per-device keys with scoping and rotation

---

## Two-Factor Authentication

### Setup Flow

1. **Enable 2FA:**
   ```
   POST /api/2fa/enable
   Authorization: (admin session)
   ```
   Response includes a `provisioning_uri` for authenticator apps (Google Authenticator, Authy, etc.) and a `secret` for manual entry.

2. **Verify & Activate:**
   ```
   POST /api/2fa/verify
   { "code": "123456" }
   ```
   On first verify, 2FA is activated and 10 backup codes are returned. Store these securely.

3. **Login with 2FA:**
   After password login, verify with TOTP code:
   ```
   POST /api/2fa/verify
   { "code": "123456", "remember_device": true, "device_fingerprint": "abc123" }
   ```
   With `remember_device: true`, the device is trusted for 30 days.

4. **Disable 2FA:**
   ```
   POST /api/2fa/disable
   { "code": "123456" }
   ```
   Requires a valid TOTP code.

5. **Regenerate Backup Codes:**
   ```
   GET /api/2fa/backup_codes
   ```
   Generates 10 new codes; previous codes are invalidated.

### Security Features

- **Lockout:** After 5 failed attempts, account is locked for 15 minutes.
- **Backup Codes:** 10 one-time-use alphanumeric codes (8 chars each).
- **Device Memory:** Trusted devices skip 2FA for 30 days.
- **Clock Drift:** ±30 seconds tolerance for TOTP codes.

---

## Session Management

### Configuration

| Env Variable | Default | Description |
|---|---|---|
| `SESSION_TIMEOUT_MINUTES` | 30 | Session inactivity timeout |
| `MAX_CONCURRENT_SESSIONS` | 3 | Max active sessions per admin |

### Behavior

- Sessions automatically expire after the configured timeout of inactivity.
- When the session limit is reached, the oldest session is deactivated.
- Each session tracks IP address, user agent, and last activity time.

### API (Internal Service)

```ruby
# Create session
SessionManager.create_session(admin_user, request)

# Validate/refresh session
SessionManager.validate_session(token)

# Force logout all devices
SessionManager.destroy_all_sessions(admin_user)

# List active sessions
SessionManager.active_sessions(admin_user)

# Cleanup expired sessions (run in scheduled job)
SessionManager.cleanup_expired
```

---

## API Key Management

### Generating Keys

```ruby
result = ApiKeyService.generate(
  name: "Device Alpha Key",
  scope: "full_access",       # or "read_only"
  device_id: "abc123",
  expires_in: 90.days
)
# result[:key] — the raw API key (shown only once!)
```

### Scopes

| Scope | Permissions |
|---|---|
| `read_only` | Query data, list commands |
| `full_access` | All operations including command execution |

### Key Rotation

```ruby
ApiKeyService.rotate(api_key_id)
# Revokes old key, generates new one with same attributes
```

### Revocation

```ruby
ApiKeyService.revoke(api_key_id)
ApiKeyService.revoke_all_for_device(device_id)
```

### Usage Tracking

Each API key tracks:
- Total usage count
- Last used timestamp
- Creation date

---

## Database Schema

### admin_two_factors
| Column | Type | Description |
|---|---|---|
| admin_user_id | FK | Owning admin (unique) |
| otp_secret | string | TOTP secret (Base32) |
| enabled | boolean | Whether 2FA is active |
| backup_codes | json | Array of one-time codes |
| last_used_at | datetime | Last successful 2FA |
| failed_attempts | integer | Consecutive failures |
| locked_until | datetime | Lockout expiry |

### admin_sessions
| Column | Type | Description |
|---|---|---|
| admin_user_id | FK | Owning admin |
| session_token | string | Unique session identifier |
| ip_address | string | Client IP |
| user_agent | string | Browser/client info |
| last_activity_at | datetime | Last request time |
| expires_at | datetime | Session expiry |
| active | boolean | Whether session is valid |

### api_keys
| Column | Type | Description |
|---|---|---|
| admin_user_id | FK (optional) | Key owner |
| device_id | string | Associated device |
| key_digest | string | SHA-256 of raw key |
| key_prefix | string | First 8 chars (for display) |
| name | string | Human-readable name |
| scope | string | read_only or full_access |
| usage_count | integer | Total uses |
| last_used_at | datetime | Last use timestamp |
| expires_at | datetime | Key expiry |
| revoked | boolean | Revocation status |
