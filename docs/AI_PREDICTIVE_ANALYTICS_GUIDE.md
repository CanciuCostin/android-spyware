# Predictive Analytics Guide

## Overview

The Predictive Analytics service analyzes historical device data to predict future locations, forecast activity patterns, calculate risk scores, and rank contact importance.

## API Endpoints

### Full Predictions
```
GET /api/ai/predictions/:device_id?days=30
```

Returns all prediction types in a single response.

### Location Prediction
```
GET /api/ai/predictions/:device_id/location
```

Predicts where the device is likely to be based on historical patterns for the current hour and day of week.

### Activity Forecast
```
GET /api/ai/predictions/:device_id/activity
```

Forecasts peak hours, busiest/quietest days, and activity trends.

### Risk Score
```
GET /api/ai/predictions/:device_id/risk
```

Calculates a composite anomaly-based risk score.

### Contact Importance
```
GET /api/ai/predictions/:device_id/contacts
```

Ranks contacts by communication frequency and recency.

## Features

### 1. Location Prediction
- Analyzes location history by hour and day of week
- Uses spatial clustering to find most probable location
- Returns predicted coordinates with confidence percentage
- Example: "On Mondays at 9:00, device is at (42.6977, 23.3219) with 85% confidence"

### 2. Activity Forecasting
- **Peak day/hour detection**: Identifies busiest times
- **Daily averages**: Average events per day of week
- **Hourly distribution**: Activity distribution across 24 hours
- **Trend analysis**: Whether activity is increasing, decreasing, or stable

### 3. Risk Scoring (Anomaly Detection)
Composite score (0–100) from four components:

| Component | Weight | What it Measures |
|-----------|--------|-----------------|
| Location anomaly | 30% | Recent locations far from historical center (>50km) |
| Activity anomaly | 25% | Deviation from average daily keylog count |
| Communication anomaly | 25% | Unusual number of unique contacts |
| Temporal anomaly | 20% | Ratio of late-night activity (00:00–05:00) |

**Risk Levels:** Low (0–20), Medium (21–50), High (51–75), Critical (76+)

### 4. Contact Importance Scoring
Combines frequency and recency:
- **Frequency** (60% weight): SMS count + 2× call count
- **Recency** (40% weight): Bonus for recent contact (100 if <1 day, 75 if <7 days, etc.)

Returns top 20 contacts sorted by importance score.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `device_id` | string | required | Device ID |
| `days` | integer | 30 | Historical period to analyze |

## Admin UI

Access via **Admin → 🧠 AI → 🔮 Predictions**. Interactive dashboard with device selector and prediction cards for location, activity, risk, and contacts.

## Service Class

```ruby
service = PredictiveAnalyticsService.new(device, days: 30)
result = service.call

# Individual methods
service.predict_next_location
service.forecast_activity
service.calculate_risk_score
service.score_contact_importance
```
