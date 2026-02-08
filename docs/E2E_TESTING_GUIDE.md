# E2E Testing Guide

End-to-end browser tests for the EagleSpy V5 admin dashboard using **RSpec + Capybara + Selenium (headless Chrome)**.

## Quick Start

```bash
# Run all system tests
bundle exec rspec spec/system/

# Run a single spec file
bundle exec rspec spec/system/dashboard_spec.rb

# With verbose output
bundle exec rspec spec/system/ --format documentation
```

## Test Suite Overview

| File | What it covers |
|------|----------------|
| `spec/system/dashboard_spec.rb` | Login flow, device cards, tab navigation, stats grid, responsive viewports, toast notifications |
| `spec/system/device_management_spec.rb` | Device list, detail page, command buttons, command history, device deletion |
| `spec/system/file_browser_spec.rb` | File browser UI, device selector, path input, Browse button, AJAX loading |
| `spec/system/geofence_spec.rb` | Create/edit/delete geofences, location history, map link |
| `spec/system/analytics_spec.rb` | Analytics dashboard, date range selector, chart containers, export menus |
| `spec/system/settings_spec.rb` | Android config, audit logs, alert rules, admin users, APK payloads, CSV export |

## Support Files

### `spec/support/capybara.rb`
- Registers a `:headless_chrome` Selenium driver
- Sets default window size to 1440×900
- Configures Puma as the test server (silent mode)
- Auto-saves screenshots to `tmp/screenshots/` on test failure

### `spec/support/system_helpers.rb`
Provides these helpers for `type: :system` specs:

| Helper | Description |
|--------|-------------|
| `admin_login` | Signs in via Devise login form |
| `wait_for_ajax` | Blocks until jQuery AJAX queue is empty |
| `wait_for_turbolinks` | Waits for Turbolinks navigation to finish |
| `javascript_errors` | Returns SEVERE-level browser console errors |
| `expect_no_javascript_errors` | RSpec matcher asserting no JS errors |
| `click_tab(label)` | Clicks a `.tab-btn` by visible text |
| `select_from_dropdown(id, value)` | Selects an `<option>` in a `<select>` |
| `create_installed_device(name:, device_id:)` | Creates a Smartphone with ApkInstallation (status=installed) |

## Writing Deterministic Tests

Per project conventions, all tests **must be deterministic**:

- Use fixed strings for names, IDs, and emails — never `SecureRandom` or `Faker`.
- Use `Time.utc(2025, 1, 15, 12, 0, 0)` or `travel_to` instead of `Time.now`.
- Stub external services (Redis, AuditService, AlertService) — the `system_helpers.rb` `before` block does this automatically.
- Avoid depending on element ordering unless explicitly sorted.

## CI Integration

The `.github/workflows/ci.yml` includes a `system_test` job that:

1. Sets up PostgreSQL, Ruby, Node.js, and Chrome
2. Installs gems and JS dependencies
3. Prepares the test database
4. Runs `bundle exec rspec spec/system/`
5. Uploads `tmp/screenshots/` as artifacts on failure (retained 7 days)

## Debugging Failures

### Locally

```bash
# Run with Chrome visible (non-headless)
HEADLESS=false bundle exec rspec spec/system/dashboard_spec.rb
```

To enable this, update `spec/support/capybara.rb` to check `ENV['HEADLESS']`.

### In CI

Failed test screenshots are uploaded as the `system-test-screenshots` artifact. Download them from the Actions run page.

### Common Issues

| Problem | Solution |
|---------|----------|
| `Selenium::WebDriver::Error::SessionNotCreatedError` | Update Chrome/Chromedriver: `bundle exec rails webdrivers:chromedriver:update` |
| Tests hang on `wait_for_ajax` | Ensure jQuery is loaded; check that the AJAX request isn't blocked by WebMock |
| `ActiveRecord::PendingMigrationError` | Run `RAILS_ENV=test bundle exec rails db:migrate` |
| Screenshots directory missing | Created automatically by `spec/support/capybara.rb` |
