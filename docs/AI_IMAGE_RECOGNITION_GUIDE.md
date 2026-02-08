# AI Image Recognition Guide

## Overview

The AI Image Recognition service provides OCR (text extraction), face detection, object detection, and EXIF metadata extraction for images. Supports Google Vision API and OpenAI Vision, with EXIF extraction working offline.

## API Endpoints

### Full Analysis
```
POST /api/ai/image/analyze
Content-Type: multipart/form-data
image: <file>
```

Or with path/URL:
```
POST /api/ai/image/analyze
Content-Type: application/json
{"image_path": "/path/to/image.jpg"}
```

### OCR (Text Extraction)
```
POST /api/ai/image/ocr
```

### Face Detection
```
POST /api/ai/image/faces
```

### Object Detection
```
POST /api/ai/image/objects
```

### Metadata Extraction
```
POST /api/ai/image/metadata
```

### Analyze Device Images
```
GET /api/ai/image/device_images/:device_id?limit=20
```

## Features

### 1. OCR (Text Extraction from Screenshots)

**Google Vision API:**
- Full text extraction with bounding boxes
- Confidence scores
- Block-level text segmentation

**OpenAI Vision:**
- Text extraction using GPT-4 Vision
- Natural language text description

**Stub mode (no API):**
- Returns EXIF metadata only
- Guidance on configuring API keys

### 2. Face Detection

**Google Vision API only:**
- Face count
- Emotion likelihood (joy, sorrow, anger, surprise)
- Bounding box coordinates
- Detection confidence

### 3. Object Detection

**Google Vision API:**
- Object labels with confidence scores
- Bounding box coordinates

**OpenAI Vision:**
- Object descriptions in natural language
- Structured JSON output

### 4. EXIF Metadata Extraction (Always Available)

Works without any external API. Extracts:

| Field | Description |
|-------|-------------|
| `filename` | Original filename |
| `file_size` | Size in bytes + human-readable |
| `mime_type` | Detected MIME type (JPEG, PNG, GIF, BMP, WebP) |
| `created_at` | File creation timestamp |
| `modified_at` | Last modification timestamp |
| `dimensions` | Width × height (JPEG/PNG) |
| `format` | Image format |
| `gps_data_present` | Whether GPS EXIF data exists |

### 5. Device Image Batch Analysis

Analyzes recent pictures from a device with configurable limit.

## API Configuration

| Environment Variable | Service | Description |
|---------------------|---------|-------------|
| `GOOGLE_VISION_API_KEY` | Google Cloud Vision | Enables OCR, face detection, object detection |
| `OPENAI_API_KEY` | OpenAI | Enables Vision-based OCR and object detection |
| `OPENAI_VISION_MODEL` | OpenAI | Vision model (default: `gpt-4o-mini`) |

### Feature Availability Matrix

| Feature | No API | Google Vision | OpenAI |
|---------|--------|--------------|--------|
| OCR | ❌ Stub | ✅ Full | ✅ Basic |
| Face Detection | ❌ Stub | ✅ Full | ❌ |
| Object Detection | ❌ Stub | ✅ Full | ✅ Basic |
| EXIF Metadata | ✅ Full | ✅ Full | ✅ Full |

## Image Format Support

Supported MIME types:
- `image/jpeg` (.jpg, .jpeg)
- `image/png` (.png)
- `image/gif` (.gif)
- `image/bmp` (.bmp)
- `image/webp` (.webp)
- `image/tiff` (.tiff)

## Admin UI

Access via **Admin → 🧠 AI → 🖼️ Image Recognition**. Features:
- API status indicators (Google Vision / OpenAI / EXIF)
- File upload for manual image analysis
- Individual analysis buttons (Full, OCR, Faces, Objects, Metadata)
- Device image batch analysis

## Service Class

```ruby
# Analyze a local file
service = ImageRecognitionService.new('/path/to/image.jpg')
result = service.call
# result.value => { ocr: {...}, faces: {...}, objects: {...}, metadata: {...} }

# Individual methods
service.extract_text
service.detect_faces
service.detect_objects
service.extract_metadata

# Batch device analysis
ImageRecognitionService.analyze_device_images(device, limit: 10)
```
