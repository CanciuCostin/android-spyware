# User Preferences Guide

## Overview

EagleSpy V5 supports per-user preferences stored as JSONB in PostgreSQL. Preferences are merged with sensible defaults so users only need to override what they want to change. A JavaScript module syncs preferences between the browser and server.

## Architecture

### Components

| Component | Path | Purpose |
|-----------|------|---------|
| Model | `app/models/user_preference.rb` | JSONB storage with default merging |
| Service | `app/services/preference_service.rb` | Validation, get/set/reset operations |
| API Controller | `app/controllers/api/preferences_controller.rb` | REST API endpoints |
| JS Module | `app/javascript/modules/preference_manager.js` | Client-side load/save/apply |

## Default Preferences

```json
{
  "dashboard": {
    "layout": "grid",
    "columns": ["status", "name", "device_id", "os", "last_activity"],
    "auto_refresh": true,
    "refresh_interval": 30
  },
  "notifications": {
    "email": true,
    "in_app": true,
    "webhook": false,
    "webhook_url": null,
    "notify_on_connect": true,
    "notify_on_disconnect": true,
    "notify_on_error": true
  },
  "theme": {
    "mode": "dark",
    "font_size": "medium",
    "accent_color": "#00d4ff",
    "compact_mode": false
  },
  "filters": {
    "default_date_range": 7,
    "saved_views": []
  },
  "data": {
    "records_per_page": 25,
    "default_sort": "created_at",
    "default_sort_direction": "desc",
    "auto_refresh_data": false
  }
}
```

## API Endpoints

### Get Preferences

```
GET /api/preferences
```

**Response:**
```json
{
  "preferences": { ... },
  "defaults": { ... }
}
```

Returns merged preferences (defaults + user overrides) and the raw defaults.

### Update Preferences

```
PUT /api/preferences
Content-Type: application/json
```

**Body:**
```json
{
  "preferences": {
    "theme": { "mode": "light", "font_size": "large" },
    "dashboard": { "layout": "list" }
  }
}
```

Only send the keys you want to change. They will be merged with existing preferences.

### Reset to Defaults

```
DELETE /api/preferences
```

Clears all user overrides and returns defaults.

## Validation Rules

The `PreferenceService` validates all incoming preferences:

| Preference | Valid Values |
|------------|-------------|
| `dashboard.layout` | `grid`, `list` |
| `dashboard.refresh_interval` | 5–300 seconds |
| `theme.mode` | `dark`, `light` |
| `theme.font_size` | `small`, `medium`, `large` |
| `theme.accent_color` | Hex color `#RRGGBB` |
| `filters.default_date_range` | 1–365 days |
| `filters.saved_views` | Max 20 views |
| `data.records_per_page` | 10–100 |
| `data.default_sort_direction` | `asc`, `desc` |
| `notifications.webhook_url` | Must start with `http://` or `https://` |

Invalid values are silently dropped.

## JavaScript Usage

### Import and Initialize

```javascript
import PreferenceManager from 'modules/preference_manager';

// On page load
PreferenceManager.init();
```

### Get/Set Values

```javascript
// Get a value (dot notation)
const layout = PreferenceManager.get('dashboard.layout', 'grid');
const theme = PreferenceManager.get('theme.mode', 'dark');

// Set a value (auto-syncs to server with debounce)
PreferenceManager.set('theme.mode', 'light');
PreferenceManager.set('dashboard.refresh_interval', 60);
```

### Reset

```javascript
await PreferenceManager.reset();
```

### Apply All

```javascript
// Re-apply all preferences to the DOM
PreferenceManager.applyAll();
```

## Ruby Usage

### In Controllers

```ruby
# Get all preferences for current user
prefs = PreferenceService.get_for(current_admin_user)

# Get a specific value
layout = PreferenceService.get_value(current_admin_user, 'dashboard.layout')

# Update preferences
PreferenceService.update_for(current_admin_user, {
  'theme' => { 'mode' => 'light' }
})

# Reset to defaults
PreferenceService.reset_for(current_admin_user)
```

### In Models

```ruby
admin_user = AdminUser.find(1)
pref = admin_user.user_preference || admin_user.create_user_preference!

# Dot-notation access
pref.get('theme.mode')       # => "dark"
pref.set('theme.mode', 'light')
pref.merged_preferences      # => full merged hash
pref.reset!                  # => clear all overrides
```

## How Defaults Work

User preferences are **merged** with defaults, not replaced:

1. `UserPreference::DEFAULTS` defines the base configuration
2. User's stored `preferences` JSONB only contains overrides
3. `merged_preferences` deep-merges overrides on top of defaults
4. Missing keys always fall back to defaults

This means:
- New defaults added in code are automatically available to all users
- Users only store what they've changed
- `reset!` simply clears the overrides hash
