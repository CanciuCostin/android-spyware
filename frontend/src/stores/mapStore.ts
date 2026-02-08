import { create } from 'zustand';
import mapboxgl from 'mapbox-gl';

export interface LocationPoint {
  id: string;
  latitude: number;
  longitude: number;
  timestamp: string;
  accuracy?: number;
  speed?: number;
  altitude?: number;
  battery?: number;
}

export interface Geofence {
  id: string;
  name: string;
  type: 'polygon' | 'circle';
  coordinates: number[][];
  radius?: number;
  color?: string;
  alertOnEntry?: boolean;
  alertOnExit?: boolean;
  createdAt?: string;
}

interface MapState {
  // Map instance
  map: mapboxgl.Map | null;
  setMap: (map: mapboxgl.Map | null) => void;

  // Map settings
  center: [number, number];
  zoom: number;
  style: string;
  setCenter: (center: [number, number]) => void;
  setZoom: (zoom: number) => void;
  setStyle: (style: string) => void;

  // Selected device
  selectedDeviceId: string | null;
  setSelectedDeviceId: (id: string | null) => void;

  // Location history
  locationHistory: LocationPoint[];
  setLocationHistory: (locations: LocationPoint[]) => void;
  addLocation: (location: LocationPoint) => void;

  // Geofences
  geofences: Geofence[];
  setGeofences: (geofences: Geofence[]) => void;
  addGeofence: (geofence: Geofence) => void;
  updateGeofence: (geofence: Geofence) => void;
  deleteGeofence: (id: string) => void;

  // UI state
  showHeatmap: boolean;
  setShowHeatmap: (show: boolean) => void;
  showGeofences: boolean;
  setShowGeofences: (show: boolean) => void;
  showLocationHistory: boolean;
  setShowLocationHistory: (show: boolean) => void;

  // Reset state
  reset: () => void;
}

const initialState = {
  map: null,
  center: [0, 0] as [number, number],
  zoom: 2,
  style: 'mapbox://styles/mapbox/dark-v11',
  selectedDeviceId: null,
  locationHistory: [],
  geofences: [],
  showHeatmap: false,
  showGeofences: true,
  showLocationHistory: true,
};

export const useMapStore = create<MapState>((set) => ({
  ...initialState,

  setMap: (map) => set({ map }),

  setCenter: (center) => set({ center }),
  setZoom: (zoom) => set({ zoom }),
  setStyle: (style) => set({ style }),

  setSelectedDeviceId: (id) => set({ selectedDeviceId: id }),

  setLocationHistory: (locations) => set({ locationHistory: locations }),
  addLocation: (location) =>
    set((state) => ({
      locationHistory: [...state.locationHistory, location],
    })),

  setGeofences: (geofences) => set({ geofences }),
  addGeofence: (geofence) =>
    set((state) => ({
      geofences: [...state.geofences, geofence],
    })),
  updateGeofence: (updatedGeofence) =>
    set((state) => ({
      geofences: state.geofences.map((g) =>
        g.id === updatedGeofence.id ? updatedGeofence : g
      ),
    })),
  deleteGeofence: (id) =>
    set((state) => ({
      geofences: state.geofences.filter((g) => g.id !== id),
    })),

  setShowHeatmap: (show) => set({ showHeatmap: show }),
  setShowGeofences: (show) => set({ showGeofences: show }),
  setShowLocationHistory: (show) => set({ showLocationHistory: show }),

  reset: () => set(initialState),
}));
