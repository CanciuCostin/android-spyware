# Scheduled Commands Guide

## Overview

Scheduled Commands allow you to automate device command execution on a time-based schedule. Commands can run once at a specific time or on a recurring cron-based schedule.

## Schedule Types

### One-time (`once`)
Executes the command at the specified `next_run_at` time, then automatically deactivates.

### Recurring (`recurring`)
Executes the command according to a cron expression. Continues until disabled or `max_runs` is reached.

## Cron Expression Format

Standard 5-field cron: `minute hour day month weekday`

| Field    | Range  | Special Characters |
|----------|--------|--------------------|
| Minute   | 0-59   | `*`, `,`, `-`, `/` |
| Hour     | 0-23   | `*`, `,`, `-`, `/` |
| Day      | 1-31   | `*`, `,`, `-`, `/` |
| Month    | 1-12   | `*`, `,`, `-`, `/` |
| Weekday  | 0-6    | `*`, `,`, `-`, `/` |

### Examples

| Expression      | Description                      |
|-----------------|----------------------------------|
| `*/5 * * * *`   | Every 5 minutes                  |
| `0 * * * *`     | Every hour                       |
| `0 9 * * 1-5`   | 9 AM on weekdays                 |
| `30 2 * * *`    | 2:30 AM daily                    |
| `0 0 1 * *`     | Midnight on the 1st of the month |
| `0 8,20 * * *`  | 8 AM and 8 PM daily              |

## API Endpoints

All endpoints require device authentication headers.

### List Scheduled Commands
```
GET /api/devices/:device_id/scheduled_commands
```
Query params: `active_only=true`, `schedule_type=once|recurring`

### Get a Scheduled Command
```
GET /api/devices/:device_id/scheduled_commands/:id
```

### Create a Scheduled Command
```
POST /api/devices/:device_id/scheduled_commands
Content-Type: application/json

{
  "scheduled_command": {
    "name": "Daily screenshot",
    "command": "take_picture",
    "params": {},
    "schedule_type": "recurring",
    "cron_expression": "0 9 * * *",
    "next_run_at": "2026-02-15T09:00:00Z"
  }
}
```

### Update a Scheduled Command
```
PATCH /api/devices/:device_id/scheduled_commands/:id
Content-Type: application/json

{
  "scheduled_command": {
    "cron_expression": "0 */2 * * *",
    "max_runs": 50
  }
}
```

### Delete a Scheduled Command
```
DELETE /api/devices/:device_id/scheduled_commands/:id
```

### Toggle Active/Inactive
```
POST /api/devices/:device_id/scheduled_commands/:id/toggle
```

### View Execution History
```
GET /api/devices/:device_id/scheduled_commands/:id/executions
```
Query params: `page=1`, `per_page=20`

## Admin Interface

The **⏰ Scheduled Commands** page in ActiveAdmin provides:
- List of all scheduled commands with status indicators
- Filtering by device, command type, schedule type, and status
- Create/edit forms with cron expression helper text
- One-click enable/disable toggle
- Execution history on the show page

## Background Job

`ScheduledCommandExecutorJob` runs periodically (every minute via your job scheduler) and:
1. Finds all active commands where `next_run_at <= now`
2. Dispatches each command via ActionCable to the device
3. Records execution results (status, duration, pending command reference)
4. Updates `next_run_at` for recurring commands
5. Deactivates one-time commands or commands that reached `max_runs`

### Setting Up the Job

Add to your job scheduler (e.g., `sidekiq-cron`, `whenever`):

```ruby
# config/sidekiq_cron.yml
scheduled_command_executor:
  cron: "* * * * *"
  class: ScheduledCommandExecutorJob

# Or with whenever (config/schedule.rb)
every 1.minute do
  runner "ScheduledCommandExecutorJob.perform_now"
end
```

## Real-time Updates

When scheduled commands execute, the results are broadcast via ActionCable to the admin dashboard. The `realtime_dashboard.js` module handles:
- Toast notifications for execution results
- Live device status updates (online/offline)
- Battery level and signal strength indicators
- Command output streaming

### Device Status Channel

Subscribe to `DeviceStatusChannel` for:
- `snapshot` – Full device state on connect
- `device_online` / `device_offline` – Connection transitions
- `device_update` – Metrics (battery, signal)
- `battery_update` – Battery level changes

## Allowed Commands

Only whitelisted commands can be scheduled:

```
send_sms, get_sms, get_device_info, start_camera, stop_camera,
get_wifi_info, get_localtime, uninstall_app, install_apk,
launch_app, get_installed_apps, get_contacts, take_picture,
screen_record, get_location, get_call_logs, get_browser_history,
toggle_wifi, set_audio_mode, get_notifications,
list_files, download_file, upload_file, delete_file, preview_file,
rename_file, move_file, search_files, upload_file_chunk
```
