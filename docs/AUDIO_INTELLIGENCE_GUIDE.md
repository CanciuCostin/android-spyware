# Audio Intelligence Guide

## Overview

The Audio Intelligence system provides speech-to-text transcription, speaker identification, language detection, audio quality analysis, and keyword spotting for recorded audio files.

## Architecture

```
Recording → AudioIntelligenceService → Transcription (STT)
                                     → Speaker Identification
                                     → Language Detection
                                     → Quality Analysis
                                     → Keyword Spotting
                                     ↓
                              AudioTranscription (DB)
                                     ↓
                              AudioIntelligence.tsx (Frontend)
```

## API Endpoints

All endpoints are under `/api/devices/:id/audio/`.

### POST /api/devices/:id/audio/transcribe

Transcribe a specific recording.

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `recording_id` | integer | Recording to transcribe (defaults to latest) |
| `language` | string | Language hint (e.g., `en`, `es`) |
| `keywords` | string/array | Comma-separated keywords to spot |
| `speakers` | string | Set to `false` to skip speaker identification |

**Response:**
```json
{
  "status": "success",
  "data": {
    "recording_id": 42,
    "duration": { "estimated_seconds": 125.3, "file_size_bytes": 2004800 },
    "quality": { "format": "mp3", "quality_tier": "high" },
    "transcription": {
      "text": "Hello, this is a test recording...",
      "language": "en",
      "confidence": 0.94,
      "provider": "whisper"
    },
    "speakers": [
      { "id": "speaker_1", "label": "Speaker 1", "duration_seconds": 65.0, "segments": [...] }
    ],
    "keywords": [
      { "keyword": "test", "count": 2, "positions": [28, 142] }
    ]
  }
}
```

### GET /api/devices/:id/audio/transcriptions

List previous transcriptions for a device.

**Parameters:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | integer | 50 | Max results |
| `offset` | integer | 0 | Pagination offset |

### POST /api/devices/:id/audio/analyze

Run full audio analysis (transcription + speakers + keywords + quality).

Same parameters as `/transcribe`.

## Service Usage

### Basic Transcription

```ruby
recording = Recording.find(42)
result = AudioIntelligenceService.call(recording)
# => { recording_id: 42, transcription: { text: "...", ... }, speakers: [...], ... }
```

### With Options

```ruby
result = AudioIntelligenceService.call(recording,
  keywords: ['password', 'secret', 'meeting'],
  language: 'en',
  speakers: true
)
```

### Keyword Spotting Only

```ruby
service = AudioIntelligenceService.new(recording, keywords: ['urgent', 'deadline'])
keywords = service.spot_keywords("This is urgent, we have a deadline tomorrow")
# => [{ keyword: "urgent", count: 1, positions: [8] }, ...]
```

## Database Model

### audio_transcriptions

| Column | Type | Description |
|--------|------|-------------|
| `recording_id` | integer | FK to recordings table |
| `text` | text | Transcribed text |
| `language` | string | Detected language code |
| `confidence` | float | Transcription confidence (0-1) |
| `speakers` | jsonb | Speaker identification data |
| `keywords` | jsonb | Matched keywords with positions |

### Migration

```bash
rails db:migrate
```

## Speech-to-Text Providers

### Google Gemini (Recommended)

Set `GEMINI_API_KEY` in your environment:

```env
GEMINI_API_KEY=your-gemini-api-key
GEMINI_MODEL=gemini-2.0-flash  # optional, defaults to gemini-2.0-flash
```

Features: Automatic language detection, high accuracy, multimodal audio understanding.

### Google Cloud Speech-to-Text

Set `GOOGLE_SPEECH_KEY` in your environment:

```env
GOOGLE_SPEECH_KEY=your-google-cloud-api-key
```

Features: Wide language support, word time offsets, automatic punctuation.

**Priority:** Whisper is used if both keys are present.

## Frontend Component

### Usage

```tsx
import AudioIntelligence from './components/AudioIntelligence';

<AudioIntelligence
  deviceId="device_123"
  recordingId={42}           // optional: specific recording
  apiBasePath="/api"         // optional: API base path
/>
```

### Features

- **Audio Player** — Integrated HTML5 audio player
- **Transcript View** — Full transcription with keyword highlighting
- **Speaker Timeline** — Color-coded timeline showing speaker segments
- **Language Indicator** — Detected language badge
- **Keywords Panel** — Matched keywords with occurrence counts
- **Transcription History** — List of previous transcriptions

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key for audio transcription | One of these |
| `GEMINI_MODEL` | Gemini model to use (default: gemini-2.0-flash) | No |
| `GOOGLE_SPEECH_KEY` | Google Cloud Speech API key | is required |
| `AUDIO_KEYWORDS` | Default keywords to spot (comma-separated) | No |

## Supported Audio Formats

`mp3`, `wav`, `ogg`, `m4a`, `aac`, `flac`, `3gp`
