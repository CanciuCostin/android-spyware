# AI Report Generation Guide

## Overview

The AI Report Generation service creates automated daily/weekly summaries for device activity, security audits, location tracking, and communication patterns. Reports include risk assessment scoring and can be exported as JSON, HTML, or PDF.

## API Endpoints

### Generate Report
```
POST /api/ai/reports/generate
```

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `device_id` | string | required | Device ID |
| `template` | string | `device_activity` | Report template |
| `format` | string | `json` | Output format: `json`, `html`, `pdf` |
| `period` | string | `weekly` | Period: `daily`, `weekly`, `monthly` |
| `start_date` | ISO 8601 | auto | Custom start date |
| `end_date` | ISO 8601 | auto | Custom end date |

**Example:**
```bash
curl -X POST http://localhost:3000/api/ai/reports/generate \
  -H "Content-Type: application/json" \
  -d '{"device_id": "abc123", "template": "security_audit", "period": "weekly"}'
```

### List Templates
```
GET /api/ai/reports/templates
```

### Risk Assessment
```
POST /api/ai/reports/risk_assessment
```

**Parameters:** `device_id` (required), `period` (optional)

## Report Templates

### 1. Device Activity (`device_activity`)
- Total commands, keylogs, SMS, calls, photos, locations
- Daily activity breakdown
- Top apps by usage
- Peak activity hours

### 2. Security Audit (`security_audit`)
- Anomaly detection (statistical deviation analysis)
- Risk level assessment
- Consent status verification
- Unusual activity indicators (e.g., late-night usage)

### 3. Location (`location`)
- Total location points and unique areas
- Estimated total distance traveled
- Frequent locations (clustered)
- Daily movement summaries
- Geofence event history

### 4. Communication (`communication`)
- SMS sent/received counts
- Call logs with duration statistics
- Top contacts by frequency
- Daily communication breakdown

## Risk Assessment Scoring

The risk score (0–100) is calculated from multiple factors:

| Factor | Weight | Trigger |
|--------|--------|---------|
| Anomalies detected | 30 | Statistical outliers in daily activity |
| Device inactive | 20 | No check-in for 24+ hours |
| No recent location | 10 | No location data in last hour |

**Risk Levels:**
- **Low** (0–25): Normal operation
- **Medium** (26–50): Minor concerns
- **High** (51–75): Significant anomalies
- **Critical** (76–100): Immediate attention needed

## Admin UI

Access via **Admin → 🧠 AI → 📄 AI Reports**. Provides interactive report generation with device/template/period/format selectors and inline risk assessment display.

## Service Class

```ruby
# Direct usage
service = ReportGenerationService.new(device,
  template: 'security_audit',
  format: 'html',
  period: 'weekly'
)
result = service.call
# result.value contains the report data or rendered HTML
```
