# EagleSpy MCP Server Guide

## Overview

The EagleSpy MCP (Model Context Protocol) Server exposes device management, data access, and analysis capabilities to AI assistants like Claude Desktop, VS Code Copilot, and other MCP-compatible clients.

## Architecture

```
app/services/mcp/
├── mcp_server.rb          # Main server: tool/resource/prompt registration
├── mcp_config.rb          # Configuration (API keys, rate limits)
├── mcp_auth.rb            # Authentication, authorization, audit logging
├── mcp_streaming.rb       # SSE streaming for live data
├── tools/
│   ├── device_tools.rb    # Device management tools
│   ├── data_tools.rb      # Data access tools
│   ├── command_tools.rb   # Command execution tools
│   └── analysis_tools.rb  # Analysis and reporting tools
├── resources/
│   └── device_resources.rb # URI-based device resources
└── prompts/
    └── prompt_templates.rb # AI prompt templates
```

## Setup

### 1. Configure API Keys

Set the `MCP_API_KEYS` environment variable. Format: `key:scope1,scope2;key2:scope3,scope4`

```bash
# .env
MCP_API_KEYS="my-secret-key:devices:read,data:read,commands:execute,analysis:read;admin-key:admin"
```

### 2. Optional Configuration

```bash
MCP_SERVER_NAME=eaglespy-mcp          # Server display name
MCP_MAX_RESULTS=100                    # Max results per query
MCP_PAGE_SIZE=25                       # Default page size
MCP_RATE_LIMIT=60                      # Requests per window
MCP_RATE_WINDOW=60                     # Rate limit window (seconds)
MCP_COMMAND_TIMEOUT=300                # Command timeout (seconds)
MCP_STREAM_HEARTBEAT=30                # SSE heartbeat interval
```

### 3. Available Scopes

| Scope | Access |
|-------|--------|
| `devices:read` | List and view device information |
| `devices:write` | Modify device settings |
| `data:read` | Access SMS, calls, contacts, photos, locations |
| `data:write` | Modify collected data |
| `commands:execute` | Send commands to devices |
| `commands:schedule` | Schedule recurring commands |
| `analysis:read` | Run analysis, generate reports |
| `admin` | Full access to all scopes |

## API Endpoints

All endpoints are under `/api/mcp/` and require authentication via `Authorization: Bearer <api_key>` or `X-API-Key` header.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/mcp/initialize` | Initialize MCP session |
| GET | `/api/mcp/tools` | List available tools |
| POST | `/api/mcp/tools/call` | Execute a tool |
| GET | `/api/mcp/resources` | List available resources |
| POST | `/api/mcp/resources/read` | Read a resource by URI |
| GET | `/api/mcp/prompts` | List available prompts |
| POST | `/api/mcp/prompts/get` | Get a prompt template |
| GET | `/api/mcp/stream/:device_id` | SSE stream for device events |
| GET | `/api/mcp/health` | Server health check |

## Available Tools

### Device Tools
- **list_devices** - List all registered devices with pagination and status filtering
- **get_device** - Get detailed device information by ID
- **get_device_status** - Get current online/offline status and connection details
- **search_devices** - Search devices by name, device_id, IP, or tag
- **get_device_stats** - Get aggregated statistics for a device

### Data Tools
- **get_locations** - Get GPS location history with time range filtering
- **get_sms_messages** - Get SMS message dumps with pagination
- **get_call_logs** - Get call log entries with pagination
- **get_contacts** - Get contact dumps with pagination
- **get_photos** - Get captured photos with pagination

### Command Tools
- **send_command** - Send a command to a device (returns tracking request ID)
- **get_command_status** - Check command status by request ID
- **get_command_history** - Get command execution history for a device
- **schedule_command** - Schedule a recurring command with cron expression

### Analysis Tools
- **analyze_behavior** - Analyze device usage patterns
- **detect_anomalies** - Detect unusual patterns (location jumps, activity spikes)
- **generate_report** - Generate comprehensive device reports
- **get_timeline** - Chronological timeline of all device events
- **search_data** - Search across all data types

## Resources (URI-based)

| URI Template | Description |
|-------------|-------------|
| `eaglespy://device/{id}` | Device details |
| `eaglespy://device/{id}/location` | Device location data |
| `eaglespy://device/{id}/sms` | Device SMS messages |
| `eaglespy://device/{id}/calls` | Device call logs |
| `eaglespy://device/{id}/contacts` | Device contacts |
| `eaglespy://device/{id}/commands` | Device command history |

## Prompt Templates

- **daily_summary** - Generate a daily activity summary across the fleet
- **behavior_analysis** - Analyze behavior patterns for a specific device
- **security_audit** - Security audit of fleet or specific device
- **location_tracking** - Analyze location and movement patterns

## Example API Calls

### List Tools
```bash
curl -H "Authorization: Bearer my-secret-key" \
  http://localhost:3000/api/mcp/tools
```

### Call a Tool
```bash
curl -X POST -H "Authorization: Bearer my-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"params":{"name":"list_devices","arguments":{"status":"online"}}}' \
  http://localhost:3000/api/mcp/tools/call
```

### Read a Resource
```bash
curl -X POST -H "Authorization: Bearer my-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"params":{"uri":"eaglespy://device/abc123"}}' \
  http://localhost:3000/api/mcp/resources/read
```

### SSE Stream
```bash
curl -H "Authorization: Bearer my-secret-key" \
  http://localhost:3000/api/mcp/stream/abc123?event_types=location,status
```
