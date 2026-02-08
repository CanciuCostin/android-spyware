# Map Components Quick Reference

## Setup

1. **Get Mapbox Token**
   ```
   https://account.mapbox.com/access-tokens/
   ```

2. **Add to .env**
   ```env
   VITE_MAPBOX_TOKEN=pk.your_token_here
   ```

## Import Components

```tsx
import { 
  DeviceMap, 
  LocationHistory, 
  HeatmapLayer, 
  GeofenceDrawer,
  LocationListView 
} from '@/components/map';
import { useMapStore } from '@/stores';
```

## DeviceMap

```tsx
<DeviceMap
  devices={devices}
  selectedDeviceId={selectedId}
  onDeviceSelect={handleSelect}
  showClustering={true}
  defaultCenter={[lng, lat]}
  defaultZoom={13}
/>
```

## LocationHistory

```tsx
<LocationHistory
  locations={locations}
  map={mapInstance}
/>
```

## HeatmapLayer

```tsx
<HeatmapLayer
  locations={locations}
  map={mapInstance}
  enabled={showHeatmap}
  onToggle={setShowHeatmap}
/>
```

## GeofenceDrawer

```tsx
<GeofenceDrawer
  map={mapInstance}
  geofences={geofences}
  onGeofenceCreate={handleCreate}
  onGeofenceUpdate={handleUpdate}
  onGeofenceDelete={handleDelete}
/>
```

## LocationListView

```tsx
<LocationListView
  locations={locations}
  onLocationClick={handleClick}
  selectedLocationId={selectedId}
/>
```

## Map Store

```tsx
const {
  map,
  setMap,
  center,
  zoom,
  selectedDeviceId,
  locationHistory,
  geofences,
  showHeatmap,
  setShowHeatmap,
  addGeofence,
  updateGeofence,
  deleteGeofence
} = useMapStore();
```

## Data Types

```typescript
interface LocationPoint {
  id: string;
  latitude: number;
  longitude: number;
  timestamp: string;
  accuracy?: number;
  speed?: number;
  altitude?: number;
}

interface Geofence {
  id: string;
  name: string;
  type: 'polygon' | 'circle';
  coordinates: number[][];
  alertOnEntry?: boolean;
  alertOnExit?: boolean;
}
```

## Export Functions

```tsx
// Export to GPX
const gpx = generateGPX(locations);

// Export to KML
const kml = generateKML(locations);

// Export to JSON
const json = JSON.stringify(locations);
```

## Map Styles

- `mapbox://styles/mapbox/dark-v11` (Dark)
- `mapbox://styles/mapbox/streets-v12` (Streets)
- `mapbox://styles/mapbox/satellite-streets-v12` (Satellite)

## Common Patterns

### Initialize Map

```tsx
useEffect(() => {
  if (!mapContainer.current || map.current) return;
  
  mapboxgl.accessToken = MAPBOX_TOKEN;
  
  map.current = new mapboxgl.Map({
    container: mapContainer.current,
    style: 'mapbox://styles/mapbox/dark-v11',
    center: [lng, lat],
    zoom: 13
  });
  
  map.current.on('load', () => {
    setMapLoaded(true);
  });
  
  return () => {
    map.current?.remove();
  };
}, []);
```

### Add Marker

```tsx
const marker = new mapboxgl.Marker()
  .setLngLat([lng, lat])
  .addTo(map);
```

### Fly to Location

```tsx
map.flyTo({
  center: [lng, lat],
  zoom: 15
});
```

### Fit Bounds

```tsx
const bounds = new mapboxgl.LngLatBounds();
locations.forEach(loc => {
  bounds.extend([loc.longitude, loc.latitude]);
});
map.fitBounds(bounds, { padding: 50 });
```

## Performance Tips

1. Use `useMemo` for computed values
2. Debounce map events
3. Limit visible markers
4. Enable clustering
5. Use GeoJSON sources
6. Lazy load components

## Debugging

```tsx
// Check if map is loaded
console.log('Map loaded:', map?.isStyleLoaded());

// Check token
console.log('Token:', import.meta.env.VITE_MAPBOX_TOKEN);

// Check WebGL support
console.log('WebGL:', mapboxgl.supported());
```
