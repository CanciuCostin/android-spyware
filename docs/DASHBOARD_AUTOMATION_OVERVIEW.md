# Dashboard & Automation Reference

This reference collates the dashboard workstreams, automated testing, CI/CD pipeline, and the security hardening steps that complement the README summary.

## Dashboard Workflow

The Command Center binds together the device registry, live telemetry, and action dispatcher into a single operator view. Devices feed a status grid, alerts surface in the live activity band, and command widgets let operators trigger Metasploit or ADB calls while streaming output to the terminal panel.

```
[Device Registry] --> [Live Activity Board] --> [Action Panel] --> [Terminal Stream]
                               ↘ [Alert Strip]
```

- **Device Registry:** fleet overview, heartbeat, and firmware metadata.
- **Live Activity Board:** recent screenshots, keylog highlights, and location updates.
- **Action Panel:** buttons that queue commands (dump contacts, stream webcam, install APK, etc.).
- **Terminal Stream:** combines ActionCable responses, Metasploit logs, and ADB output for auditability.

## Testing Process

RSpec, Capybara, and smoke tests cover the model, controller, and UI layers. Local runs mirror the CI workflow so developers can reproduce failures and submit clear artifacts to the team.

```
[Unit Specs] + [Feature Specs]
          ↘ [GitHub Actions Test Matrix] ↘ [HTML Reports / Coverage]
```

- **Unit Specs:** `spec/models` / `spec/services` guard critical business logic.
- **Feature Specs:** Capybara-driven flows verify Remote control pages and dashboard states.
- **Smoke Jobs:** Quick sanity checks after helper changes (e.g., `utils/` scripts).

## Automation & CI/CD Pipeline

GitHub Actions orchestrates dependency installs, linters, full test suites, security scanning, and container lifecycle steps on every push or pull request. Failures stop the pipeline before Docker builds or deployments can proceed.

```
[Push | PR] --> [Install Dependencies] --> [Lint + Specs] --> [Docker Build + Scan] --> [Deploy/Notify]
```

- **Install dependencies:** `bundle install`, `npm/yarn install`.
- **Lint + Specs:** Ruby linters + RSpec + Capybara + Cypress (if configured).
- **Docker Build + Scan:** Multi-stage build followed by security scan (trivy or similar).
- **Deploy/Notify:** Optional artifact upload and deployment to staging / production.

## Security Hardening Steps

The security checklist `docs/SECURITY_SETUP.md` should accompany this reference. The dashboard and automation layers assume the credentials, networking, TLS, and logging posture outlined in that guide.

1. Regenerate every secret (database, Rails secret key base, TURN, MSF, device token).
2. Harden the `.env` file with unique values and limit port exposure to `80/443` and `3478`.
3. Keep Docker containers in an internal bridge network, avoid binding the Docker socket, and monitor logs (`log/security.log`).
4. Enforce TLS via `USE_SSL=true` and a hardened reverse proxy.
5. Keep Rack::Attack rate limits active and review audit logs daily.

## References

- README new sections (dashboard, testing, automation, security summaries).
- [`docs/SECURITY_SETUP.md`](SECURITY_SETUP.md) for the full checklist.
