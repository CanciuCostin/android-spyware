import React, { useState, useEffect, useRef, useMemo } from 'react';
import mapboxgl from 'mapbox-gl';
import 'mapbox-gl/dist/mapbox-gl.css';
import { Card, CardHeader, CardTitle, CardContent } from '../ui';
import { LocationHistory, HeatmapLayer, GeofenceDrawer, LocationListView } from '../map';
import { useMapStore } from '../../stores/mapStore';
import { Layers } from 'lucide-react';

interface LocationTabProps {
  deviceId: string;
}

interface LocationPoint {
  id: string;
  latitude: number;
  longitude: number;
  accuracy?: number;
  speed?: number;
  timestamp: string;
}

export const LocationTab: React.FC<LocationTabProps> = ({ deviceId }) => {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const markerRef = useRef<mapboxgl.Marker | null>(null);
  const [mapLoaded, setMapLoaded] = useState(false);

  const {
    showHeatmap,
    setShowHeatmap,
    geofences,
    addGeofence,
    updateGeofence,
    deleteGeofence,
  } = useMapStore();

  // Mock data - replace with actual API call
  const [locations] = useState<LocationPoint[]>([
    {
      id: '1',
      latitude: 42.3601,
      longitude: -71.0589,
      accuracy: 15,
      speed: 2.5,
      timestamp: new Date(Date.now() - 3600000).toISOString(),
    },
    {
      id: '2',
      latitude: 42.3611,
      longitude: -71.0579,
      accuracy: 20,
      speed: 3.2,
      timestamp: new Date(Date.now() - 7200000).toISOString(),
    },
    {
      id: '3',
      latitude: 42.3621,
      longitude: -71.0569,
      accuracy: 18,
      speed: 1.8,
      timestamp: new Date(Date.now() - 10800000).toISOString(),
    },
  ]);

  const [selectedLocation, setSelectedLocation] = useState<LocationPoint | null>(
    locations[0] || null
  );

  const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN || '';

  // Calculate statistics
  const stats = useMemo(() => {
    if (locations.length === 0) {
      return { totalDistance: 0, avgSpeed: 0, maxSpeed: 0 };
    }

    let totalDistance = 0;
    let totalSpeed = 0;
    let maxSpeed = 0;
    let speedCount = 0;

    for (let i = 1; i < locations.length; i++) {
      const prev = locations[i - 1];
      const curr = locations[i];
      
      // Calculate distance using Haversine formula
      const distance = calculateDistance(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude
      );
      totalDistance += distance;

      if (curr.speed !== undefined) {
        totalSpeed += curr.speed;
        maxSpeed = Math.max(maxSpeed, curr.speed);
        speedCount++;
      }
    }

    return {
      totalDistance: totalDistance / 1000, // Convert to km
      avgSpeed: speedCount > 0 ? totalSpeed / speedCount : 0,
      maxSpeed,
    };
  }, [locations]);

  // Initialize map
  useEffect(() => {
    if (!mapContainer.current || map.current || !MAPBOX_TOKEN) return;

    mapboxgl.accessToken = MAPBOX_TOKEN;

    const centerLat = locations.length > 0 ? locations[0].latitude : 0;
    const centerLng = locations.length > 0 ? locations[0].longitude : 0;

    map.current = new mapboxgl.Map({
      container: mapContainer.current,
      style: 'mapbox://styles/mapbox/dark-v11',
      center: [centerLng, centerLat],
      zoom: 13,
    });

    map.current.addControl(new mapboxgl.NavigationControl(), 'top-right');
    map.current.addControl(new mapboxgl.FullscreenControl(), 'top-right');

    map.current.on('load', () => {
      setMapLoaded(true);
    });

    return () => {
      if (markerRef.current) {
        markerRef.current.remove();
      }
      map.current?.remove();
      map.current = null;
    };
  }, [MAPBOX_TOKEN]);

  // Update marker when selected location changes
  useEffect(() => {
    if (!map.current || !mapLoaded || !selectedLocation) return;

    if (markerRef.current) {
      markerRef.current.remove();
    }

    const el = document.createElement('div');
    el.className = 'w-10 h-10 bg-electric-500 rounded-full flex items-center justify-center shadow-lg';
    el.innerHTML = `
      <svg class="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 24 24">
        <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
      </svg>
    `;

    markerRef.current = new mapboxgl.Marker({ element: el })
      .setLngLat([selectedLocation.longitude, selectedLocation.latitude])
      .addTo(map.current);

    map.current.flyTo({
      center: [selectedLocation.longitude, selectedLocation.latitude],
      zoom: 15,
    });
  }, [selectedLocation, mapLoaded]);

  const handleLocationClick = (location: LocationPoint) => {
    setSelectedLocation(location);
  };

  if (!MAPBOX_TOKEN) {
    return (
      <div className="flex items-center justify-center min-h-[600px]">
        <Card variant="glass" className="p-8 text-center max-w-md">
          <div className="text-6xl mb-4">🗺️</div>
          <CardTitle className="mb-2">Mapbox Token Required</CardTitle>
          <p className="text-white/60 text-sm">
            Please add your Mapbox token to the <code className="bg-dark-800 px-2 py-1 rounded">.env</code> file
          </p>
          <p className="text-white/40 text-xs mt-2">
            VITE_MAPBOX_TOKEN=your_token_here
          </p>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Map View */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <Card variant="glass" className="h-[600px]">
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="flex items-center gap-2">
                  <Layers className="w-5 h-5" />
                  Location Map
                </CardTitle>
              </div>
            </CardHeader>
            <CardContent className="h-[calc(100%-80px)] relative">
              <div ref={mapContainer} className="w-full h-full rounded-lg" />
              
              {/* Map Controls */}
              {mapLoaded && (
                <>
                  <div className="absolute top-4 left-4 z-10">
                    <HeatmapLayer
                      locations={locations}
                      map={map.current}
                      enabled={showHeatmap}
                      onToggle={setShowHeatmap}
                    />
                  </div>

                  <div className="absolute top-16 left-4 z-10">
                    <GeofenceDrawer
                      map={map.current}
                      geofences={geofences}
                      onGeofenceCreate={addGeofence}
                      onGeofenceUpdate={updateGeofence}
                      onGeofenceDelete={deleteGeofence}
                    />
                  </div>

                  {locations.length > 0 && (
                    <div className="absolute bottom-4 left-0 right-0 px-4 z-10">
                      <LocationHistory locations={locations} map={map.current} />
                    </div>
                  )}
                </>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Stats Sidebar */}
        <div className="space-y-6">
          <Card variant="glass">
            <CardHeader>
              <CardTitle>Statistics</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <StatItem label="Total Locations" value={locations.length.toString()} />
              <StatItem label="Distance Traveled" value={`${stats.totalDistance.toFixed(2)} km`} />
              <StatItem label="Avg Speed" value={`${stats.avgSpeed.toFixed(1)} m/s`} />
              <StatItem label="Max Speed" value={`${stats.maxSpeed.toFixed(1)} m/s`} />
              <StatItem
                label="Last Update"
                value={locations[0] ? new Date(locations[0].timestamp).toLocaleString() : 'N/A'}
              />
            </CardContent>
          </Card>

          {selectedLocation && (
            <Card variant="glass">
              <CardHeader>
                <CardTitle>Selected Location</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div>
                  <div className="text-xs text-white/40 mb-1">Coordinates</div>
                  <div className="text-sm font-mono text-white">
                    {selectedLocation.latitude.toFixed(6)}, {selectedLocation.longitude.toFixed(6)}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-white/40 mb-1">Timestamp</div>
                  <div className="text-sm text-white">
                    {new Date(selectedLocation.timestamp).toLocaleString()}
                  </div>
                </div>
                {selectedLocation.accuracy && (
                  <div>
                    <div className="text-xs text-white/40 mb-1">Accuracy</div>
                    <div className="text-sm text-white">±{selectedLocation.accuracy}m</div>
                  </div>
                )}
                {selectedLocation.speed !== undefined && (
                  <div>
                    <div className="text-xs text-white/40 mb-1">Speed</div>
                    <div className="text-sm text-white">{selectedLocation.speed.toFixed(2)} m/s</div>
                  </div>
                )}
              </CardContent>
            </Card>
          )}
        </div>
      </div>

      {/* Location List */}
      <LocationListView
        locations={locations}
        onLocationClick={handleLocationClick}
        selectedLocationId={selectedLocation?.id}
      />
    </div>
  );
};

const StatItem: React.FC<{ label: string; value: string }> = ({ label, value }) => (
  <div className="flex justify-between items-center">
    <span className="text-white/60 text-sm">{label}</span>
    <span className="text-white font-medium">{value}</span>
  </div>
);

// Haversine formula to calculate distance between two coordinates
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}
