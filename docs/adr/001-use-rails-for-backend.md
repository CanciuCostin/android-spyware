# ADR-001: Use Ruby on Rails for Backend

**Date:** 2020-01-01  
**Status:** Accepted

## Context

EagleSpy needs a backend framework to serve a web UI, expose REST/WebSocket
APIs, manage a PostgreSQL database, and orchestrate device commands. The team
had experience with Ruby and needed rapid prototyping with conventions over
configuration.

Alternatives considered:
- **Django (Python)** — strong ORM but weaker real-time WebSocket story at the
  time (pre-Channels maturity).
- **Express/Node.js** — excellent WebSocket support but less opinionated; would
  require assembling many libraries.
- **Spring Boot (Java)** — enterprise-grade but high ceremony for a small team.

## Decision

Use **Ruby on Rails ~> 6.0** as the primary backend framework.

Key factors:
1. **Convention over configuration** — reduces boilerplate for CRUD, migrations,
   and admin interfaces.
2. **ActiveAdmin + Devise** — provides an admin panel and authentication
   out-of-the-box.
3. **ActionCable** — built-in WebSocket support for real-time device
   communication without an external broker.
4. **Ecosystem maturity** — battle-tested gems for background jobs (Sidekiq),
   security (Rack::Attack, bcrypt), and testing (RSpec).

## Consequences

### Positive
- Rapid development; admin UI stood up within days.
- Single codebase for REST API, WebSocket channels, and admin views.
- Large pool of available gems for almost every need.

### Negative
- Ruby's per-process memory footprint is higher than Node.js or Go.
- ActionCable's threading model requires care under high concurrency.
- Deployment requires a Ruby runtime, adding container image size compared to
  compiled languages.
- Rails 6 is approaching end-of-life; an upgrade to Rails 7+ will be needed.
