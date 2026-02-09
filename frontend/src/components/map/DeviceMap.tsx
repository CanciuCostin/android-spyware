import React, { useRef, useEffect, useState, useMemo } from 'react';
import mapboxgl from 'mapbox-gl';
import 'mapbox-gl/dist/mapbox-gl.css';
import { MapPin, Maximize2, Locate } from 'lucide-react';

interface Device {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  status: 'online' | 'offline' | 'idle';
  lastSeen?: string;
}

interface DeviceMapProps {
  devices: Device[];
  selectedDeviceId?: string;
  onDeviceSelect?: (deviceId: string) => void;
  showClustering?: boolean;
  defaultCenter?: [number, number];
  defaultZoom?: number;
  className?: string;
}

const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN || '';
const DEFAULT_STYLE = 'mapbox://styles/mapbox/dark-v11';

const MAP_STYLES = [
  { id: 'dark-v11', label: 'Dark', icon: '🌙' },
  { id: 'streets-v12', label: 'Streets', icon: '🗺️' },
  { id: 'satellite-streets-v12', label: 'Satellite', icon: '🛰️' },
];

export const DeviceMap: React.FC<DeviceMapProps> = ({
  devices,
  selectedDeviceId,
  onDeviceSelect,
  showClustering = true,
  defaultCenter = [0, 0],
  defaultZoom = 2,
  className = '',
}) => {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const markers = useRef<Map<string, mapboxgl.Marker>>(new Map());
  const [mapLoaded, setMapLoaded] = useState(false);
  const [currentStyle, setCurrentStyle] = useState(DEFAULT_STYLE);
  const [isFullscreen, setIsFullscreen] = useState(false);

  // Initialize map
  useEffect(() => {
    if (!mapContainer.current || map.current) return;
    if (!MAPBOX_TOKEN) {
      console.warn('Mapbox token not provided');
      return;
    }

    mapboxgl.accessToken = MAPBOX_TOKEN;

    map.current = new mapboxgl.Map({
      container: mapContainer.current,
      style: currentStyle,
      center: defaultCenter,
      zoom: defaultZoom,
      attributionControl: false,
    });

    map.current.addControl(new mapboxgl.NavigationControl(), 'top-right');
    map.current.addControl(
      new mapboxgl.GeolocateControl({
        positionOptions: { enableHighAccuracy: true },
        trackUserLocation: true,
      }),
      'top-right'
    );
    map.current.addControl(new mapboxgl.FullscreenControl(), 'top-right');
    map.current.addControl(new mapboxgl.ScaleControl(), 'bottom-right');

    map.current.on('load', () => {
      setMapLoaded(true);
    });

    map.current.on('fullscreenchange', () => {
      setIsFullscreen(!isFullscreen);
    });

    return () => {
      markers.current.forEach((marker) => marker.remove());
      markers.current.clear();
      map.current?.remove();
      map.current = null;
    };
  }, []);

  // Change map style
  useEffect(() => {
    if (!map.current || !mapLoaded) return;
    map.current.setStyle(`mapbox://styles/mapbox/${currentStyle}`);
  }, [currentStyle, mapLoaded]);

  // Update markers when devices change
  useEffect(() => {
    if (!map.current || !mapLoaded) return;

    // Remove old markers
    markers.current.forEach((marker, id) => {
      if (!devices.find((d) => d.id === id)) {
        marker.remove();
        markers.current.delete(id);
      }
    });

    // Add or update markers
    devices.forEach((device) => {
      let marker = markers.current.get(device.id);

      if (!marker) {
        // Create new marker
        const el = createMarkerElement(device, device.id === selectedDeviceId);
        marker = new mapboxgl.Marker({ element: el })
          .setLngLat([device.longitude, device.latitude])
          .addTo(map.current!);

        // Add popup
        const popup = new mapboxgl.Popup({ offset: 25 }).setHTML(`
          <div class="p-2">
            <h3 class="font-bold text-sm mb-1">${device.name}</h3>
            <p class="text-xs text-gray-600">Status: <span class="${getStatusClass(device.status)}">${device.status}</span></p>
            ${device.lastSeen ? `<p class="text-xs text-gray-500 mt-1">Last seen: ${new Date(device.lastSeen).toLocaleString()}</p>` : ''}
          </div>
        `);

        marker.setPopup(popup);

        // Add click handler
        el.addEventListener('click', () => {
          onDeviceSelect?.(device.id);
        });

        markers.current.set(device.id, marker);
      } else {
        // Update existing marker position
        marker.setLngLat([device.longitude, device.latitude]);
        
        // Update marker appearance if selection changed
        const el = marker.getElement();
        const isSelected = device.id === selectedDeviceId;
        updateMarkerElement(el, device, isSelected);
      }
    });

    // Fit bounds if multiple devices
    if (devices.length > 1) {
      const bounds = new mapboxgl.LngLatBounds();
      devices.forEach((device) => {
        bounds.extend([device.longitude, device.latitude]);
      });
      map.current.fitBounds(bounds, { padding: 50, maxZoom: 15 });
    } else if (devices.length === 1) {
      map.current.flyTo({
        center: [devices[0].longitude, devices[0].latitude],
        zoom: 13,
      });
    }
  }, [devices, mapLoaded, selectedDeviceId, onDeviceSelect]);

  const centerOnDevice = (deviceId: string) => {
    const device = devices.find((d) => d.id === deviceId);
    if (device && map.current) {
      map.current.flyTo({
        center: [device.longitude, device.latitude],
        zoom: 15,
      });
    }
  };

  const handleStyleChange = (styleId: string) => {
    setCurrentStyle(`mapbox://styles/mapbox/${styleId}`);
  };

  if (!MAPBOX_TOKEN) {
    return (
      <div className={`flex items-center justify-center bg-dark-800 rounded-lg ${className}`}>
        <div className="text-center p-8">
          <MapPin className="w-16 h-16 text-white/20 mx-auto mb-4" />
          <p className="text-white/60 mb-2">Mapbox token not configured</p>
          <p className="text-sm text-white/40">Add VITE_MAPBOX_TOKEN to your .env file</p>
        </div>
      </div>
    );
  }

  return (
    <div className={`relative ${className}`}>
      <div ref={mapContainer} className="w-full h-full rounded-lg" />

      {/* Style Selector */}
      <div className="absolute top-4 left-4 flex gap-2 z-10">
        {MAP_STYLES.map((style) => (
          <button
            key={style.id}
            onClick={() => handleStyleChange(style.id)}
            className={`
              px-3 py-2 rounded-lg backdrop-blur-md transition-all
              ${
                currentStyle.includes(style.id)
                  ? 'bg-electric-500 text-dark-900 shadow-lg'
                  : 'bg-dark-900/80 text-white/80 hover:bg-dark-800/90'
              }
            `}
            title={style.label}
          >
            <span className="mr-2">{style.icon}</span>
            <span className="text-xs font-medium">{style.label}</span>
          </button>
        ))}
      </div>

      {/* Device Counter */}
      {devices.length > 0 && (
        <div className="absolute top-4 right-20 bg-dark-900/90 backdrop-blur-md px-4 py-2 rounded-lg z-10">
          <span className="text-white/60 text-xs mr-2">Devices:</span>
          <span className="text-white font-medium">{devices.length}</span>
        </div>
      )}
    </div>
  );
};

// Helper functions
function createMarkerElement(device: Device, isSelected: boolean): HTMLDivElement {
  const el = document.createElement('div');
  updateMarkerElement(el, device, isSelected);
  return el;
}

function updateMarkerElement(el: HTMLElement, device: Device, isSelected: boolean): void {
  el.className = `
    w-10 h-10 rounded-full flex items-center justify-center
    cursor-pointer transition-all shadow-lg
    ${getStatusBgClass(device.status)}
    ${isSelected ? 'ring-4 ring-electric-500 scale-125' : 'hover:scale-110'}
  `;
  el.innerHTML = `
    <svg class="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 24 24">
      <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
    </svg>
  `;
}

function getStatusBgClass(status: string): string {
  switch (status) {
    case 'online':
      return 'bg-green-500';
    case 'idle':
      return 'bg-yellow-500';
    case 'offline':
      return 'bg-red-500';
    default:
      return 'bg-gray-500';
  }
}

function getStatusClass(status: string): string {
  switch (status) {
    case 'online':
      return 'text-green-600 font-medium';
    case 'idle':
      return 'text-yellow-600 font-medium';
    case 'offline':
      return 'text-red-600 font-medium';
    default:
      return 'text-gray-600';
  }
}
