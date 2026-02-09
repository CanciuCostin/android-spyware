# ADR-006: Consent Management System

**Date:** 2025-06-01  
**Status:** Accepted

## Context

EagleSpy collects sensitive data from Android devices. To operate within legal
and ethical boundaries (even for educational/authorized-use scenarios), the
platform needs an auditable consent mechanism that tracks which data collection
activities have been explicitly authorized for each device installation.

Alternatives considered:
- **No consent tracking** — simplest but creates legal liability and makes
  auditing impossible.
- **External consent management platform** — overkill for the project's scope
  and adds a third-party dependency.

## Decision

Implement a **built-in consent management** system with the following models:

| Model                | Purpose                                       |
|----------------------|-----------------------------------------------|
| `DeviceConsent`      | Per-device consent status (granted/revoked)    |
| `DataUsageDisclosure`| What data is collected and why                |
| `TermsAcceptance`    | Record of terms acceptance with timestamp     |

API:
- `POST /apk_installations/consents/grant` — grant a consent type.
- `POST /apk_installations/consents/revoke` — revoke a consent type.
- Managed via `ConsentService` and `ConsentController`.

Consent types are linked to APK installations, so each deployed APK has an
independent consent record. The `AuditLog` model records every grant/revoke
action for compliance.

## Consequences

### Positive
- Full audit trail — every consent change is logged with timestamp and admin
  user.
- Granular control — individual data collection features can be toggled per
  device.
- Supports compliance reporting; consent records can be exported.

### Negative
- Adds operational overhead — admins must manage consents before activating
  features.
- Consent enforcement depends on the Android client respecting server-side
  flags; a modified client could bypass checks.
- The model is basic (grant/revoke); more complex consent workflows (e.g.,
  expiring consents) would require extension.
