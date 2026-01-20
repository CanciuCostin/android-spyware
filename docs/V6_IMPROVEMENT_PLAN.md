# EagleSpy V6 Improvement Plan - 30 TODOs

## Phase 1: Core Infrastructure (1-5)
1. **Upgrade to Ruby 3.x**: Migrate from Ruby 2.6.6 to Ruby 3.2+ for performance and security patches.
2. **Upgrade to Rails 7.x**: Update from Rails 6.0 to Rails 7.1 with Hotwire/Turbo integration.
3. **Replace Webpacker with ESBuild**: Modern JS bundling with 10x faster build times.
4. **Add Redis for ActionCable**: Real-time WebSocket support for live device status updates.
5. **Implement Sidekiq for Background Jobs**: Move long-running MSF/ADB operations to async workers.

## Phase 2: Security Hardening (6-10)
6. **Add 2FA (Two-Factor Authentication)**: TOTP-based login for admin users.
7. **Implement JWT API Authentication**: Secure API endpoints for mobile/external access.
8. **Add Content Security Policy (CSP)**: Prevent XSS attacks with strict CSP headers.
9. **Encrypt Sensitive Data at Rest**: Use `attr_encrypted` for GPS coordinates and messages.
10. **Add Audit Logging**: Track all admin actions (who did what, when) with PaperTrail gem.

## Phase 3: User Experience (11-15)
11. **Responsive Mobile UI**: Make ActiveAdmin fully responsive for tablet/phone access.
12. **Dark/Light Theme Toggle**: Let users switch between themes (currently only dark).
13. **Real-Time Device Status Widget**: WebSocket-powered live connection indicators.
14. **Push Notifications**: Browser notifications when new data arrives from devices.
15. **Multi-Language Support (i18n)**: Add Bulgarian, Spanish, Russian language packs.

## Phase 4: Data & Analytics (16-20)
16. **Advanced Analytics Dashboard**: Charts for device activity over time (Chart.js/ApexCharts).
17. **Export to CSV/PDF**: Download call logs, SMS, contacts as spreadsheet/PDF.
18. **Full-Text Search**: Elasticsearch integration for searching across all collected data.
19. **Geofencing Alerts**: Notify when device enters/exits predefined geographic zones.
20. **Data Visualization: Heatmaps**: Show device movement patterns on map with heatmap overlay.

## Phase 5: Device Capabilities (21-25)
21. **Screen Mirroring (scrcpy integration)**: Live screen view via ADB.
22. **File Browser UI**: Navigate and download files from device storage.
23. **App Manager**: List, install, uninstall apps from the web UI.
24. **Remote Shell Terminal**: Interactive terminal in browser (xterm.js + WebSocket).
25. **Scheduled Tasks**: Cron-like scheduler for automated data collection (e.g., GPS every hour).

## Phase 6: DevOps & Quality (26-30)
26. **CI/CD Pipeline (GitHub Actions)**: Automated testing, linting, and Docker builds on push.
27. **Kubernetes Deployment Manifests**: K8s YAML for scalable cloud deployment.
28. **End-to-End Tests (Cypress)**: Browser automation tests for critical workflows.
29. **API Documentation (Swagger UI)**: Interactive API explorer served at /api-docs.
30. **Performance Monitoring (Prometheus + Grafana)**: Metrics dashboard for system health.

---

## Priority Matrix

| Priority | Items | Effort |
|----------|-------|--------|
| 🔴 Critical | 6, 7, 9, 10, 26 | High |
| 🟠 High | 1, 2, 5, 13, 24 | Medium-High |
| 🟡 Medium | 3, 4, 11, 16, 21 | Medium |
| 🟢 Low | 12, 14, 15, 17-20 | Low-Medium |

---

## Estimated Timeline

- **Phase 1**: 2-3 weeks
- **Phase 2**: 2 weeks
- **Phase 3**: 1-2 weeks
- **Phase 4**: 2-3 weeks
- **Phase 5**: 3-4 weeks
- **Phase 6**: 1-2 weeks

**Total**: ~12-16 weeks for full V6 release.
