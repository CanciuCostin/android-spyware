# MCP Client Integration Guide

## Claude Desktop

### Configuration

Add to your Claude Desktop `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "eaglespy": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "http://localhost:3000/api/mcp"
      ],
      "env": {
        "MCP_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

**Config file locations:**
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`

### Usage

Once configured, Claude can:
- List and search devices: "Show me all online devices"
- Query device data: "Get the last 10 GPS locations for device abc123"
- Send commands: "Take a screenshot on device abc123"
- Analyze patterns: "Detect anomalies on device abc123 over the last 7 days"
- Generate reports: "Generate a security audit report for the entire fleet"

## VS Code Extension

### Setup with Copilot

1. Install the MCP extension for VS Code
2. Add to `.vscode/settings.json`:

```json
{
  "mcp.servers": {
    "eaglespy": {
      "url": "http://localhost:3000/api/mcp",
      "headers": {
        "Authorization": "Bearer your-api-key-here"
      }
    }
  }
}
```

### Setup with Continue.dev

Add to `~/.continue/config.json`:

```json
{
  "mcpServers": [
    {
      "name": "eaglespy",
      "transport": {
        "type": "sse",
        "url": "http://localhost:3000/api/mcp/stream"
      },
      "auth": {
        "type": "bearer",
        "token": "your-api-key-here"
      }
    }
  ]
}
```

## Direct HTTP Integration

### Initialize Session

```bash
curl -X POST http://localhost:3000/api/mcp/initialize \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1}'
```

### List Available Tools

```bash
curl http://localhost:3000/api/mcp/tools \
  -H "Authorization: Bearer your-api-key"
```

### Call a Tool

```bash
curl -X POST http://localhost:3000/api/mcp/tools/call \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "list_devices",
      "arguments": {"status": "online", "per_page": 10}
    },
    "id": 2
  }'
```

### Read a Resource

```bash
curl -X POST http://localhost:3000/api/mcp/resources/read \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "resources/read",
    "params": {
      "uri": "eaglespy://device/abc123/location"
    },
    "id": 3
  }'
```

### Get a Prompt

```bash
curl -X POST http://localhost:3000/api/mcp/prompts/get \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "prompts/get",
    "params": {
      "name": "daily_summary",
      "arguments": {"date": "2024-12-01"}
    },
    "id": 4
  }'
```

### SSE Stream (Live Data)

```bash
curl -N http://localhost:3000/api/mcp/stream/abc123 \
  -H "Authorization: Bearer your-api-key" \
  -H "Accept: text/event-stream"
```

Query parameters:
- `event_types` - Comma-separated list: `location`, `command`, `status` (default: all)

### Health Check

```bash
curl http://localhost:3000/api/mcp/health \
  -H "Authorization: Bearer your-api-key"
```

## Authentication

All requests require one of:
- `Authorization: Bearer <api_key>` header
- `X-API-Key: <api_key>` header
- `api_key` query parameter

## Rate Limiting

- Default: 60 requests per 60-second window
- `X-RateLimit-Remaining` in response indicates remaining quota
- 429 status returned when limit exceeded

## Error Handling

Errors follow JSON-RPC 2.0 format:

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32601,
    "message": "Unknown tool: invalid_tool"
  },
  "id": 1
}
```

| Code | Meaning |
|------|---------|
| -32600 | Authorization / rate limit error |
| -32601 | Tool / resource / prompt not found |
| -32602 | Invalid parameters |
| -32603 | Internal error |
