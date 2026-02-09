# Geofencing & Location Tracking Guide

## Overview

EagleSpy V5 includes a full geofencing and location tracking system that allows you to:

- **Define geofences** — circular zones (lat/lng + radius) or polygon zones
- **Track entry/exit events** — automatic alerts when a device enters or leaves a geofence
- **Location history playback** — timeline slider to replay a device's movement
- **Heatmap visualization** — density map of frequently visited locations
- **Real-time alerts** — ActionCable broadcasts + AlertService integration

## Architecture

```
Android Client                    Rails Backend                 Frontend
┌─────────────────┐     POST     ┌──────────────────────┐     ┌──────────────────┐
│ GeofenceService │ ──────────── │ GeofenceController   │     │ GeofenceManager  │
│  (Kotlin)       │   /api/      │  receive / CRUD      │     │  (React/TSX)     │
└─────────────────┘  geofence    └──────┬───────────────┘     └──────┬───────────┘
                                        │                            │
                                 ┌──────▼───────────────┐     ┌─────▼────────────┐
                                 │ GeofenceService       │     │ GeofenceDrawer   │
                                 │  (Haversine/Ray cast) │     │ HeatmapLayer     │
                                 └──────┬───────────────┘     │ LocationHistory  │
                                        │                     │ DeviceMap        │
                                 ┌──────▼───────────────┐     └──────────────────┘
                                 │ AlertService          │
                                 │ ActionCable broadcast │
                                 └──────────────────────┘
```

## Backend

### Models

#### Geofence

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Human-readable name |
| `smartphone_id` | references | Associated device |
| `lat` | float | Center latitude (circle mode) |
| `lng` | float | Center longitude (circle mode) |
| `radius_meters` | float | Radius in meters (circle mode) |
| `polygon_points` | json | Array of `[lng, lat]` coordinate pairs (polygon mode) |
| `active` | boolean | Whether geofence is actively monitored |
| `alert_on_entry` | boolean | Alert when device enters zone |
| `alert_on_exit` | boolean | Alert when device exits zone |

A geofence must define either a circle (lat + lng + radius) or a polygon (≥3 points).

#### GeofenceEvent

| Field | Type | Description |
|-------|------|-------------|
| `smartphone_id` | references | Device that triggered the event |
| `geofence_id` | references | Which geofence was triggered |
| `event_type` | string | `entry` or `exit` |
| `lat` | float | Device latitude at trigger time |
| `lng` | float | Device longitude at trigger time |
| `triggered_at` | datetime | When the event occurred |

### API Endpoints

All endpoints are under the `/api` namespace and require device authentication.

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/geofence` | Receive geofence alert from Android client |
| `POST` | `/api/devices/:device_id/geofences` | Create a new geofence |
| `GET` | `/api/devices/:device_id/geofences` | List all geofences for a device |
| `DELETE` | `/api/devices/:device_id/geofences/:id` | Delete a geofence |
| `GET` | `/api/devices/:device_id/location_history` | Get location history with optional date range |
| `GET` | `/api/devices/:device_id/location_heatmap` | Get heatmap data (last N days) |
| `GET` | `/api/devices/:device_id/geofence_events` | Get geofence entry/exit events |

#### Create Geofence (Circle)

```bash
curl -X POST /api/devices/DEVICE_ID/geofences \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Office",
    "lat": 42.6977,
    "lng": 23.3219,
    "radius_meters": 500,
    "alert_on_entry": true,
    "alert_on_exit": true
  }'
```

#### Create Geofence (Polygon)

```bash
curl -X POST /api/devices/DEVICE_ID/geofences \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Campus",
    "polygon_points": [[23.32, 42.69], [23.33, 42.69], [23.33, 42.70], [23.32, 42.70]],
    "alert_on_entry": true,
    "alert_on_exit": false
  }'
```

#### Location History with Date Range

```bash
curl "/api/devices/DEVICE_ID/location_history?from=2025-01-01T00:00:00Z&to=2025-01-31T23:59:59Z&limit=200"
```

#### Heatmap Data

```bash
curl "/api/devices/DEVICE_ID/location_heatmap?days=30"
```

### GeofenceService

The service handles all geospatial calculations:

- **Circle geofences** — Uses the **Haversine formula** to calculate great-circle distance between the device position and the geofence center
- **Polygon geofences** — Uses the **ray casting algorithm** to determine if a point is inside an arbitrary polygon
- **State tracking** — Compares current position against the last recorded event to detect transitions (entry → exit or vice versa)
- **Alert integration** — Triggers `AlertService` for `geofence_entry` and `geofence_exit` events
- **ActionCable broadcast** — Pushes real-time updates to the `geofence_stream` channel

### ResponseProcessor

`GeofenceResponseProcessor` is registered in the `COMMAND_PROCESSORS` map for the `geofence_event` command type. It processes responses from the Android client and delegates to `GeofenceService`.

## Android Client

The Kotlin `GeofenceService` (`android-client/.../services/GeofenceService.kt`) uses Google Play Services `GeofencingClient` to:

1. Register circular geofences on the device
2. Listen for `GEOFENCE_TRANSITION_ENTER` and `GEOFENCE_TRANSITION_EXIT` events
3. POST alerts to `/api/geofence` with device coordinates and zone info

The service is started via Intent with extras:
- `action`: `add`, `remove`, or `trigger`
- `latitude`, `longitude`: center coordinates
- `radius`: radius in meters
- `label`: geofence identifier

## Frontend

### GeofenceManager Component

`frontend/src/components/GeofenceManager.tsx` is the main UI component with four tabs:

1. **Geofences** — Draw, view, and delete geofences on the map using `GeofenceDrawer`
2. **History** — Location playback with timeline slider using `LocationHistory`
3. **Heatmap** — Toggle density overlay using `HeatmapLayer`
4. **Events** — Scrollable list of entry/exit events with timestamps

Usage:

```tsx
import { GeofenceManager } from './components/GeofenceManager';

<GeofenceManager
  deviceId="abc123"
  deviceName="Pixel 7"
  apiBaseUrl="/api"
  className="h-[600px]"
/>
```

### Map Sub-components

All located in `frontend/src/components/map/`:

| Component | Purpose |
|-----------|---------|
| `DeviceMap` | Base Mapbox GL map with device markers |
| `GeofenceDrawer` | Draw/edit/delete polygon geofences on map |
| `HeatmapLayer` | Configurable heatmap overlay with radius/intensity controls |
| `LocationHistory` | Timeline playback with animated marker and path line |
| `LocationListView` | Tabular view of location data |

## Database Migration

Run the migration to create the required tables:

```bash
rails db:migrate
```

This creates:
- `geofences` table with indexes on `smartphone_id` and `active`
- `geofence_events` table with indexes on `smartphone_id`, `triggered_at`, and `event_type`
