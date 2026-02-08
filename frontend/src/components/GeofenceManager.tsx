import React, { useState, useEffect, useCallback } from 'react';
import mapboxgl from 'mapbox-gl';
import 'mapbox-gl/dist/mapbox-gl.css';
import {
  MapPin, Plus, Trash2, Shield, Bell, Clock, Flame,
  Eye, EyeOff, RefreshCw, ChevronDown, ChevronUp
} from 'lucide-react';
import { DeviceMap } from './map/DeviceMap';
import { GeofenceDrawer } from './map/GeofenceDrawer';
import { HeatmapLayer } from './map/HeatmapLayer';
import { LocationHistory } from './map/LocationHistory';

interface Geofence {
  id: string;
  name: string;
  type: 'polygon' | 'circle';
  coordinates: number[][];
  radius?: number;
  color?: string;
  alertOnEntry?: boolean;
  alertOnExit?: boolean;
  active?: boolean;
}

interface GeofenceEvent {
  id: string;
  geofence_id: string;
  geofence_name: string;
  event_type: 'entry' | 'exit';
  latitude: number;
  longitude: number;
  triggered_at: string;
}

interface LocationPoint {
  id: string;
  latitude: number;
  longitude: number;
  timestamp: string;
  accuracy?: number;
  speed?: number;
}

interface GeofenceManagerProps {
  deviceId: string;
  deviceName?: string;
  apiBaseUrl?: string;
  className?: string;
}

type TabId = 'geofences' | 'history' | 'heatmap' | 'events';

const API_BASE = '/api';

async function apiFetch<T>(url: string, options?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...options?.headers },
    ...options,
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  const json = await res.json();
  return json.data ?? json;
}

export const GeofenceManager: React.FC<GeofenceManagerProps> = ({
  deviceId,
  deviceName,
  apiBaseUrl = API_BASE,
  className = '',
}) => {
  const [activeTab, setActiveTab] = useState<TabId>('geofences');
  const [map, setMap] = useState<mapboxgl.Map | null>(null);
  const [geofences, setGeofences] = useState<Geofence[]>([]);
  const [events, setEvents] = useState<GeofenceEvent[]>([]);
  const [locations, setLocations] = useState<LocationPoint[]>([]);
  const [heatmapLocations, setHeatmapLocations] = useState<LocationPoint[]>([]);
  const [heatmapEnabled, setHeatmapEnabled] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [panelOpen, setPanelOpen] = useState(true);

  const base = `${apiBaseUrl}/devices/${deviceId}`;

  // Fetch geofences
  const fetchGeofences = useCallback(async () => {
    try {
      const data = await apiFetch<any[]>(`${base}/geofences`);
      setGeofences(
        data.map((g: any) => ({
          id: String(g.id),
          name: g.name,
          type: g.polygon_points ? 'polygon' : 'circle',
          coordinates: g.polygon_points || [[g.lng, g.lat]],
          radius: g.radius_meters,
          alertOnEntry: g.alert_on_entry,
          alertOnExit: g.alert_on_exit,
          active: g.active,
        }))
      );
    } catch (e: any) {
      setError(e.message);
    }
  }, [base]);

  // Fetch events
  const fetchEvents = useCallback(async () => {
    try {
      const data = await apiFetch<GeofenceEvent[]>(`${base}/geofence_events`);
      setEvents(data);
    } catch (e: any) {
      setError(e.message);
    }
  }, [base]);

  // Fetch location history
  const fetchLocationHistory = useCallback(async () => {
    try {
      const data = await apiFetch<LocationPoint[]>(`${base}/location_history`);
      setLocations(data);
    } catch (e: any) {
      setError(e.message);
    }
  }, [base]);

  // Fetch heatmap data
  const fetchHeatmapData = useCallback(async () => {
    try {
      const data = await apiFetch<LocationPoint[]>(`${base}/location_heatmap?days=30`);
      setHeatmapLocations(data);
    } catch (e: any) {
      setError(e.message);
    }
  }, [base]);

  // Load data on mount
  useEffect(() => {
    setLoading(true);
    Promise.all([fetchGeofences(), fetchLocationHistory()]).finally(() => setLoading(false));
  }, [fetchGeofences, fetchLocationHistory]);

  // Load tab-specific data
  useEffect(() => {
    if (activeTab === 'events') fetchEvents();
    if (activeTab === 'heatmap') fetchHeatmapData();
  }, [activeTab, fetchEvents, fetchHeatmapData]);

  const handleGeofenceCreate = async (geofence: Geofence) => {
    try {
      const body: any = {
        name: geofence.name,
        alert_on_entry: geofence.alertOnEntry ?? true,
        alert_on_exit: geofence.alertOnExit ?? false,
      };

      if (geofence.type === 'circle' && geofence.coordinates.length === 1) {
        body.lng = geofence.coordinates[0][0];
        body.lat = geofence.coordinates[0][1];
        body.radius_meters = geofence.radius || 200;
      } else {
        body.polygon_points = geofence.coordinates;
      }

      await apiFetch(`${base}/geofences`, {
        method: 'POST',
        body: JSON.stringify(body),
      });
      await fetchGeofences();
    } catch (e: any) {
      setError(e.message);
    }
  };

  const handleGeofenceUpdate = async (geofence: Geofence) => {
    // Optimistic update for drawing changes
    setGeofences((prev) => prev.map((g) => (g.id === geofence.id ? geofence : g)));
  };

  const handleGeofenceDelete = async (id: string) => {
    try {
      await apiFetch(`${base}/geofences/${id}`, { method: 'DELETE' });
      setGeofences((prev) => prev.filter((g) => g.id !== id));
    } catch (e: any) {
      setError(e.message);
    }
  };

  const handleRefresh = async () => {
    setLoading(true);
    setError(null);
    try {
      await Promise.all([fetchGeofences(), fetchLocationHistory(), fetchEvents()]);
    } finally {
      setLoading(false);
    }
  };

  const tabs: { id: TabId; label: string; icon: React.ReactNode }[] = [
    { id: 'geofences', label: 'Geofences', icon: <Shield className="w-4 h-4" /> },
    { id: 'history', label: 'History', icon: <Clock className="w-4 h-4" /> },
    { id: 'heatmap', label: 'Heatmap', icon: <Flame className="w-4 h-4" /> },
    { id: 'events', label: 'Events', icon: <Bell className="w-4 h-4" /> },
  ];

  return (
    <div className={`flex flex-col h-full bg-dark-900 rounded-xl overflow-hidden ${className}`}>
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 bg-dark-800/80 border-b border-white/5">
        <div className="flex items-center gap-3">
          <MapPin className="w-5 h-5 text-electric-400" />
          <div>
            <h2 className="text-white font-semibold text-sm">Geofence Manager</h2>
            {deviceName && (
              <p className="text-white/50 text-xs">{deviceName}</p>
            )}
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleRefresh}
            disabled={loading}
            className="p-2 bg-dark-700 hover:bg-dark-600 rounded-lg transition-colors disabled:opacity-50"
            title="Refresh"
          >
            <RefreshCw className={`w-4 h-4 text-white/70 ${loading ? 'animate-spin' : ''}`} />
          </button>
          <button
            onClick={() => setPanelOpen(!panelOpen)}
            className="p-2 bg-dark-700 hover:bg-dark-600 rounded-lg transition-colors"
          >
            {panelOpen ? (
              <ChevronDown className="w-4 h-4 text-white/70" />
            ) : (
              <ChevronUp className="w-4 h-4 text-white/70" />
            )}
          </button>
        </div>
      </div>

      {/* Error Banner */}
      {error && (
        <div className="px-4 py-2 bg-red-500/20 border-b border-red-500/30">
          <p className="text-red-400 text-xs">{error}</p>
        </div>
      )}

      {/* Tabs */}
      <div className="flex border-b border-white/5">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`
              flex items-center gap-2 px-4 py-2.5 text-xs font-medium transition-colors
              ${activeTab === tab.id
                ? 'text-electric-400 border-b-2 border-electric-400 bg-electric-500/5'
                : 'text-white/50 hover:text-white/80 hover:bg-white/5'
              }
            `}
          >
            {tab.icon}
            {tab.label}
          </button>
        ))}
      </div>

      {/* Main Content */}
      <div className="flex-1 relative min-h-[400px]">
        {/* Map fills the entire area */}
        <div className="absolute inset-0">
          <DeviceMap
            devices={locations.length > 0 ? [{
              id: deviceId,
              name: deviceName || deviceId,
              latitude: locations[0].latitude,
              longitude: locations[0].longitude,
              status: 'online',
            }] : []}
            className="w-full h-full"
          />
        </div>

        {/* Overlay controls based on active tab */}
        {panelOpen && (
          <div className="absolute inset-0 pointer-events-none">
            <div className="pointer-events-auto">
              {activeTab === 'geofences' && (
                <div className="absolute top-4 left-4 z-10">
                  <GeofenceDrawer
                    map={map}
                    geofences={geofences}
                    onGeofenceCreate={handleGeofenceCreate}
                    onGeofenceUpdate={handleGeofenceUpdate}
                    onGeofenceDelete={handleGeofenceDelete}
                  />
                </div>
              )}

              {activeTab === 'history' && (
                <div className="absolute bottom-4 left-4 right-4 z-10">
                  <LocationHistory
                    locations={locations}
                    map={map}
                  />
                </div>
              )}

              {activeTab === 'heatmap' && (
                <div className="absolute top-4 left-4 z-10">
                  <HeatmapLayer
                    locations={heatmapLocations}
                    map={map}
                    enabled={heatmapEnabled}
                    onToggle={setHeatmapEnabled}
                  />
                </div>
              )}

              {activeTab === 'events' && (
                <div className="absolute top-4 right-4 z-10 bg-dark-900/95 backdrop-blur-md rounded-lg p-4 shadow-xl max-w-[350px] max-h-[400px] overflow-y-auto">
                  <h3 className="text-white font-medium text-sm mb-3">Geofence Events</h3>
                  {events.length === 0 ? (
                    <p className="text-white/40 text-xs text-center py-4">No events recorded</p>
                  ) : (
                    <div className="space-y-2">
                      {events.map((event) => (
                        <div
                          key={event.id}
                          className="p-3 bg-white/5 rounded-lg border border-white/5"
                        >
                          <div className="flex items-center justify-between mb-1">
                            <span className="text-white text-xs font-medium">
                              {event.geofence_name}
                            </span>
                            <span
                              className={`
                                text-[10px] font-bold uppercase px-2 py-0.5 rounded-full
                                ${event.event_type === 'entry'
                                  ? 'bg-green-500/20 text-green-400'
                                  : 'bg-red-500/20 text-red-400'
                                }
                              `}
                            >
                              {event.event_type === 'entry' ? '📥 Entry' : '📤 Exit'}
                            </span>
                          </div>
                          <div className="text-white/40 text-[10px]">
                            <span>{event.latitude.toFixed(6)}, {event.longitude.toFixed(6)}</span>
                            <span className="mx-1">·</span>
                            <span>{new Date(event.triggered_at).toLocaleString()}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
