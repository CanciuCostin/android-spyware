# Smart Geofencing Guide

## Overview

The Smart Geofencing service uses location history analysis to automatically detect home/work locations, suggest geofences for frequent places, predict routes, and detect anomalous movement patterns.

## API Endpoints

### Full Analysis
```
GET /api/ai/geofencing/:device_id?days=30
```

### Detect Places (Home/Work)
```
GET /api/ai/geofencing/:device_id/places
```

### Suggest Geofences
```
GET /api/ai/geofencing/:device_id/suggestions
```

### Route Predictions
```
GET /api/ai/geofencing/:device_id/routes
```

### Route Anomalies
```
GET /api/ai/geofencing/:device_id/anomalies
```

## Features

### 1. Auto-Detect Home/Work
Uses time-of-day heuristics to classify locations:
- **Home hours**: 21:00–06:00 — Location clusters during these hours are labeled "Home"
- **Work hours**: 09:00–17:00 — Location clusters during these hours are labeled "Work"

The algorithm clusters location points using a 300m radius and selects the largest cluster for each category.

**Response:**
```json
{
  "home": { "latitude": 42.6977, "longitude": 23.3219, "confidence": 78.5, "visits": 142 },
  "work": { "latitude": 42.6500, "longitude": 23.3800, "confidence": 65.2, "visits": 89 }
}
```

### 2. Geofence Suggestions
Analyzes all location points to find clusters with ≥3 visits, then suggests geofences:
- Automatic naming (Home/Work/Frequent based on visit times)
- Dynamic radius based on visit count (150m–500m)
- Peak hours for each location
- Confidence scoring

### 3. Route Prediction
Predicts upcoming movements based on historical transitions for the current day of week:
- Filters significant movements (>500m)
- Groups by hour and selects most common destination
- Provides confidence based on consistency

### 4. Route Anomaly Detection
Two types of anomalies detected:

| Anomaly Type | Description | Severity |
|-------------|-------------|----------|
| `unusual_speed` | Movement speed >200 km/h between consecutive points | Medium (>200) / High (>500) |
| `unexpected_location` | Current location >10km from expected place (home/work) | Medium (>10km) / High (>50km) |

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `device_id` | string | required | Device ID |
| `days` | integer | 30 | Historical period to analyze |

## Algorithm Details

### Clustering
Uses a greedy point-clustering approach:
1. For each unused point, find all points within `CLUSTER_RADIUS_KM` (0.3 km)
2. Mark all nearby points as used
3. Calculate cluster center as average of member coordinates
4. Record peak hours and visit counts

### Haversine Distance
All distance calculations use the Haversine formula for accurate great-circle distances on Earth's surface.

## Admin UI

Access via **Admin → 🧠 AI → 🗺️ Smart Geofencing**. Interactive dashboard with buttons for place detection, geofence suggestions, route predictions, and anomaly detection.

## Service Class

```ruby
service = SmartGeofencingService.new(device, days: 30)
result = service.call

# Individual methods
service.detect_places       # Home/work detection
service.suggest_geofences   # Geofence suggestions
service.predict_routes      # Route predictions
service.detect_route_anomalies  # Anomaly detection
```
