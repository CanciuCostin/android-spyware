# AI Chat Assistant Guide

## Overview

The AI Chat Assistant provides a natural language interface to query device data. Users can ask questions like "Show calls to John" or "Where was device yesterday" and receive structured responses with tables, charts, and maps.

## API Endpoints

### Chat
```
POST /api/ai/chat
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `device_id` | string | Device ID (required) |
| `message` | string | Natural language query (required) |
| `history` | array | Conversation history for multi-turn context |

**Example:**
```bash
curl -X POST http://localhost:3000/api/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"device_id": "abc123", "message": "Show calls to John"}'
```

**Response:**
```json
{
  "role": "assistant",
  "content": "Found 5 call(s) matching 'John':",
  "type": "table",
  "data": [
    {"number": "+1234567890", "type": "outgoing", "duration": 120, "date": "2024-01-15 14:30"}
  ],
  "visualization": {"type": "table", "columns": ["number", "type", "duration", "date"]},
  "context": {"device_id": "abc123", "query": "Show calls to John", "timestamp": "..."}
}
```

### Capabilities
```
GET /api/ai/chat/capabilities
```

Returns available commands and whether AI mode is enabled.

## Supported Queries

| Query Pattern | Example | Response Type |
|--------------|---------|---------------|
| Show calls to [name] | "Show calls to John" | Table |
| Show SMS from/to [contact] | "Show SMS from Mom" | Table |
| Where was device [time] | "Where was device yesterday" | Map |
| How many [type] | "How many SMS today" | Text |
| Top contacts | "Top contacts" | Bar chart |
| Activity summary | "Activity summary" | Summary |
| App usage | "Top apps used" | Pie chart |
| Risk/anomalies | "Any anomalies?" | Alert |
| Help | "help" | Info |

## Modes of Operation

### 1. Pattern Matching (Default)
Works without any external API. Uses regex patterns to parse natural language queries and translates them directly to database queries.

### 2. AI-Powered (with OpenAI)
When `OPENAI_API_KEY` is configured, queries are sent to OpenAI for more sophisticated natural language understanding. The AI model generates structured database queries from arbitrary natural language input.

**Environment Variables:**
- `OPENAI_API_KEY` — OpenAI API key (enables AI mode)
- `OPENAI_MODEL` — Model to use (default: `gpt-4o-mini`)

## Multi-Turn Conversations

Pass previous messages in the `history` array to maintain conversation context:

```json
{
  "device_id": "abc123",
  "message": "And what about yesterday?",
  "history": [
    {"role": "user", "content": "Show calls to John"},
    {"role": "assistant", "content": "Found 5 calls..."}
  ]
}
```

## Response Types

| Type | Description | Visualization |
|------|-------------|--------------|
| `table` | Tabular data | Column-based table |
| `chart` | Chart data | Pie/bar chart |
| `map` | Location points | Map with markers |
| `text` | Plain text | Formatted text |
| `summary` | Overview stats | Dashboard cards |
| `alert` | Risk/anomaly info | Alert banner |
| `info` | Help/info text | Info panel |

## Admin UI

Access via **Admin → 🧠 AI → 🤖 AI Chat**. The existing AI Chat admin page integrates with this service.

## Service Class

```ruby
service = AiChatService.new(device, "Show calls to John", history: [])
result = service.call
# result.value => { role: 'assistant', content: '...', type: 'table', data: [...] }
```
