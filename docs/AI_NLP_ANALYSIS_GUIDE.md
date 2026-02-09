# NLP Analysis Guide

## Overview

The NLP Analysis service provides text analysis capabilities including entity extraction, sentiment analysis, language detection, and PII (Personally Identifiable Information) detection with redaction. Works with SMS messages and any arbitrary text input.

## API Endpoints

### Full Analysis
```
POST /api/ai/nlp/analyze
Content-Type: application/json
{"text": "Hello John, my email is john@example.com and my SSN is 123-45-6789"}
```

### Entity Extraction
```
POST /api/ai/nlp/entities
```

### Sentiment Analysis
```
POST /api/ai/nlp/sentiment
```

### Language Detection
```
POST /api/ai/nlp/language
```

### PII Detection
```
POST /api/ai/nlp/pii
```

### Analyze Device Messages
```
GET /api/ai/nlp/device_messages/:device_id?limit=100
```

Batch-analyzes SMS messages for a device with aggregate statistics.

## Features

### 1. Entity Extraction

**Without API (pattern-based):**
- Phone numbers (international formats)
- Email addresses
- URLs
- IP addresses
- Proper nouns (capitalized words, filtered for sentence starters)

**With Google Gemini API:**
- People names
- Places/locations
- Organizations
- Dates and times

### 2. Sentiment Analysis

**Lexicon-based (default):**
Uses built-in positive/negative word lists to calculate a sentiment score from -1.0 (very negative) to +1.0 (very positive).

| Score Range | Label |
|------------|-------|
| > 0.2 | Positive |
| -0.2 to 0.2 | Neutral |
| < -0.2 | Negative |

**AI-powered (with Google Gemini):**
More nuanced sentiment analysis with explanation text.

### 3. Language Detection

Detects language using trigram word frequency matching. Supported languages:
- English (en), Spanish (es), French (fr), German (de)
- Bulgarian (bg), Russian (ru), Portuguese (pt), Italian (it)

Returns confidence score based on matching word frequency.

### 4. PII Detection & Redaction

Detects and redacts sensitive information:

| PII Type | Risk Level | Redaction |
|----------|-----------|-----------|
| SSN (###-##-####) | Critical | `[SSN REDACTED]` |
| Credit card numbers | Critical | `[CC REDACTED]` |
| Email addresses | Medium | `[EMAIL REDACTED]` |
| Phone numbers | Medium | `[PHONE REDACTED]` |
| IP addresses | Low | Detected but not redacted |

### 5. Device Message Analysis

Batch analysis of SMS messages with aggregate statistics:
- Average sentiment across all messages
- Total PII findings by type
- Per-message detailed analysis

## Environment Variables

| Variable | Description |
|----------|-------------|
| `GEMINI_API_KEY` | Enables AI-powered entity extraction and sentiment analysis |
| `GEMINI_MODEL` | Model to use (default: `gemini-2.0-flash`) |

## Admin UI

Access via **Admin → 🧠 AI → 📝 NLP Analysis**. Provides:
- Text input area for manual analysis
- Buttons for each analysis type (full, entities, sentiment, language, PII)
- Device message batch analysis with limit selector

## Service Class

```ruby
# Analyze arbitrary text
service = NlpAnalysisService.new("Hello, my email is test@example.com")
result = service.call
# result.value => { entities: {...}, sentiment: {...}, language: {...}, pii: {...}, summary: {...} }

# Individual methods
service.extract_entities
service.analyze_sentiment
service.detect_language
service.detect_pii
service.redact_text

# Batch device analysis
NlpAnalysisService.analyze_device_messages(device, limit: 50)
```
