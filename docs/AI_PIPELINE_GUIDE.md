# AI Pipeline Guide

## Overview

The AI Pipeline provides real-time processing of incoming device data through a configurable, plugin-based architecture. It supports anomaly detection, data enrichment, and real-time alerting via ActionCable.

## Architecture

```
Device Data → PipelineManager → [AnomalyDetector] → [DataEnricher] → Alerts/Enriched Data
                    ↓
             ActionCable (ai_pipeline channel)
                    ↓
             Admin Dashboard
```

### Components

| Component | File | Purpose |
|-----------|------|---------|
| PipelineManager | `app/services/ai_pipeline/pipeline_manager.rb` | Orchestrates processing stages, priority queue |
| AnomalyDetector | `app/services/ai_pipeline/anomaly_detector.rb` | Statistical & behavioral anomaly detection |
| DataEnricher | `app/services/ai_pipeline/data_enricher.rb` | Geocoding, contact resolution, app categorization |
| AiPipelineChannel | `app/channels/ai_pipeline_channel.rb` | Real-time WebSocket updates |
| Admin Dashboard | `app/admin/ai_pipeline.rb` | Pipeline status, anomaly alerts, manual triggers |

## Usage

### Basic Processing

```ruby
pipeline = AiPipeline::PipelineManager.new
pipeline.register(AiPipeline::AnomalyDetector.new, priority: :high)
pipeline.register(AiPipeline::DataEnricher.new, priority: :normal)

result = pipeline.process('device_123', 'keylog', { text: 'hello world' })
# => { anomalies: [...], enrichments: {...}, metadata: {...} }
```

### Queue-Based Processing

```ruby
pipeline = AiPipeline::PipelineManager.new
pipeline.register(AiPipeline::AnomalyDetector.new)

# Enqueue items
pipeline.enqueue('device_1', 'sms', { phone_number: '+1234567890' }, priority: :high)
pipeline.enqueue('device_1', 'location', { latitude: 40.7, longitude: -74.0 })

# Process all queued items
results = pipeline.process_queue
```

### Background Processing

```ruby
pipeline = AiPipeline::PipelineManager.new
pipeline.register(AiPipeline::AnomalyDetector.new)
pipeline.start  # Starts background worker thread
# ... enqueue items ...
pipeline.stop   # Graceful shutdown
```

### Custom Processor Plugin

Create a processor that responds to `handles?` and `process`:

```ruby
class MyCustomProcessor
  def handles?(data_type)
    data_type.to_s == 'custom_type'
  end

  def process(context)
    # context[:payload] - the raw data
    # context[:enrichments] - add enrichments here
    # context[:anomalies] - add anomalies here
    context[:enrichments][:my_data] = 'enriched'
    context
  end
end

pipeline.register(MyCustomProcessor.new, stage: :custom, priority: :low)
```

## Anomaly Detection

### Detection Methods

1. **Z-Score** — Flags data points with z-score > 2.5 (configurable)
2. **IQR (Interquartile Range)** — Identifies outliers outside Q1-1.5×IQR to Q3+1.5×IQR
3. **Location Anomaly** — Detects positions >50km from known device clusters
4. **Usage Pattern** — Flags activity during typically inactive hours

### Baseline Profiling

```ruby
baseline = AiPipeline::AnomalyDetector.build_baseline(device, period_days: 30)
# => { keylog_hourly: {...}, sms_daily: [...], location_clusters: [...] }
```

### Anomaly Severities

| Severity | Trigger |
|----------|---------|
| Critical | Z-score > 4.0 |
| High | Z-score > 2.5, unusual location |
| Medium | IQR outlier, unusual usage hours |

## Data Enrichment

### Features

- **Geocoding** — Reverse-geocode coordinates to addresses (requires `GEOCODING_API_KEY`)
- **Contact Resolution** — Match phone numbers to device contacts
- **App Categorization** — Categorize apps by package name (messaging, social, browser, etc.)
- **Metadata Tagging** — Add timestamps, day-of-week, and processing metadata

## Real-Time Updates (ActionCable)

### Subscribe to Pipeline Events

```javascript
const subscription = App.cable.subscriptions.create(
  { channel: 'AiPipelineChannel', device_id: 'device_123' },
  {
    received(data) {
      console.log('Pipeline event:', data.event, data.data);
    }
  }
);
```

### Events

| Event | Description |
|-------|-------------|
| `enqueued` | Data item added to processing queue |
| `completed` | Processing finished for an item |
| `status` | Pipeline status update |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GEOCODING_API_KEY` | Google Maps Geocoding API key | — |
| `ANOMALY_LOCATION_THRESHOLD_KM` | Distance threshold for location anomalies | `50` |

## Admin Dashboard

Access at **Admin → 🧠 AI → 🔄 AI Pipeline**:

- **Pipeline Status** — Running state, processed count, error count, queue size
- **Anomaly Alerts** — Recent anomaly-triggered alerts with severity and details
- **Manual Trigger** — Select a device and data type to run the pipeline on demand
