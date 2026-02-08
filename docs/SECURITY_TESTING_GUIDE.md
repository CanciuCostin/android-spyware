# Security Testing Guide

This guide covers the security testing infrastructure for EagleSpy V5, including rate limiting, authentication, authorization, injection prevention, and OWASP Top 10 compliance.

## Table of Contents

- [Rate Limiting (Rack::Attack)](#rate-limiting-rackattack)
- [Security Test Suite](#security-test-suite)
- [Running Security Tests](#running-security-tests)
- [Rate Limit Service](#rate-limit-service)
- [OWASP Top 10 Coverage](#owasp-top-10-coverage)

---

## Rate Limiting (Rack::Attack)

### Configuration

Rate limiting is configured in `config/initializers/rack_attack.rb` with the following throttle rules:

| Rule              | Limit         | Period  | Scope         |
|-------------------|---------------|---------|---------------|
| `auth/ip`         | 5 req/min     | 1 min   | Per IP        |
| `uploads/device`  | 10 req/min    | 1 min   | Per Device ID |
| `commands/device` | 30 req/min    | 1 min   | Per Device ID |
| `api/ip`          | 100 req/min   | 1 min   | Per IP        |
| `websocket/ip`    | 5 req/min     | 1 min   | Per IP        |
| `admin/ip`        | 20 req/min    | 1 min   | Per IP        |
| `req/device`      | 90 req/min    | 1 min   | Per Device ID |
| `req/ip`          | 300 req/5min  | 5 min   | Per IP        |

### Environment Variables

- `RATE_LIMIT_PER_IP` — Override API general limit (default: 100)
- `RATE_LIMIT_PER_DEVICE` — Override device general limit (default: 90)

### Safelist

Internal/loopback IPs are automatically safelisted:
- `127.0.0.1`, `::1`
- `10.x.x.x`, `192.168.x.x`, `172.16-31.x.x`

### Blocklist

IPs can be dynamically blocked via `RateLimitService.block_ip(ip)`.

### Throttle Response

Throttled requests receive:
- **Status:** `429 Too Many Requests`
- **Headers:** `Retry-After`, `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- **Body:** JSON with `error`, `retry_after`, and `throttle` fields

### Exponential Backoff

Repeated throttle violations trigger escalating blocks. After 3+ violations within 10 minutes, requests are automatically blocked at increasing levels.

---

## Security Test Suite

### Test Files

| File | Description |
|------|-------------|
| `spec/requests/rate_limiting_spec.rb` | Rate limiting & RateLimitService tests |
| `spec/security/authentication_spec.rb` | Login, session, token, CSRF tests |
| `spec/security/authorization_spec.rb` | Admin access, device isolation, route protection |
| `spec/security/injection_spec.rb` | SQL injection, XSS, command injection, path traversal |
| `spec/security/owasp_top10_spec.rb` | OWASP A01, A02, A03, A05, A07 coverage |

---

## Running Security Tests

```bash
# Run all security tests
bundle exec rspec spec/security/ spec/requests/rate_limiting_spec.rb

# Run specific test file
bundle exec rspec spec/security/authentication_spec.rb

# Run with verbose output
bundle exec rspec spec/security/ --format documentation

# Run OWASP tests only
bundle exec rspec spec/security/owasp_top10_spec.rb
```

---

## Rate Limit Service

`RateLimitService` (`app/services/rate_limit_service.rb`) provides programmatic control over rate limiting:

### Check Status

```ruby
RateLimitService.rate_limit_status('api/ip', '192.168.1.100')
# => { throttle: 'api/ip', limit: 100, remaining: 95, blocked: false, ... }
```

### Block/Unblock IPs

```ruby
RateLimitService.block_ip('10.0.0.99', duration: 2.hours)
RateLimitService.unblock_ip('10.0.0.99')
RateLimitService.blocked?('10.0.0.99')
```

### Reset Counters

```ruby
RateLimitService.reset('192.168.1.100')
```

### Get Statistics

```ruby
RateLimitService.statistics
# => [{ name: 'auth/ip', limit: 5, period: 60, description: '...' }, ...]
```

### Instance Usage

```ruby
result = RateLimitService.call('192.168.1.100')
result.success? # => true
result.value    # => Array of status hashes for all throttle rules
```

---

## OWASP Top 10 Coverage

| OWASP ID | Category | Test Coverage |
|----------|----------|---------------|
| A01 | Broken Access Control | Admin auth enforcement, forced browsing, CORS |
| A02 | Cryptographic Failures | bcrypt cost factor, timing-safe comparison, HMAC-SHA256 |
| A03 | Injection | SQL injection, XSS, command injection in login & API |
| A05 | Security Misconfiguration | Stack traces, security headers, Rack::Attack config |
| A07 | Cross-Site Scripting | XSS sanitization, event handlers, protocol handlers, CSRF tokens |

### Input Validation

The `InputValidator` service (`app/services/input_validator.rb`) provides centralized validation:

- `contains_sql_injection?(value)` — Detects SQL injection patterns
- `sanitize_sql_input(value)` — Removes dangerous SQL characters
- `contains_xss?(value)` — Detects XSS patterns
- `sanitize_xss(value)` — HTML-encodes dangerous characters
- `remove_null_bytes(value)` — Strips null bytes
- `validate_file_path(path, base_dir:)` — Prevents path traversal

---

## Adding New Security Tests

1. Place tests in `spec/security/` for security-focused tests
2. Place tests in `spec/requests/` for HTTP-level integration tests
3. Use `type: :request` for full-stack request tests
4. Reset `Rack::Attack` state in `before`/`after` blocks for determinism
5. Test both positive (allowed) and negative (blocked) cases
6. Document which OWASP category each test covers
