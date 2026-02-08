import React, { useEffect, useState } from 'react';
import mapboxgl from 'mapbox-gl';
import { Flame, Settings } from 'lucide-react';

interface LocationPoint {
  latitude: number;
  longitude: number;
  timestamp?: string;
}

interface HeatmapLayerProps {
  locations: LocationPoint[];
  map: mapboxgl.Map | null;
  enabled?: boolean;
  onToggle?: (enabled: boolean) => void;
  className?: string;
}

export const HeatmapLayer: React.FC<HeatmapLayerProps> = ({
  locations,
  map,
  enabled = false,
  onToggle,
  className = '',
}) => {
  const [isEnabled, setIsEnabled] = useState(enabled);
  const [radius, setRadius] = useState(20);
  const [intensity, setIntensity] = useState(1);
  const [showSettings, setShowSettings] = useState(false);

  // Initialize heatmap layer
  useEffect(() => {
    if (!map || !map.isStyleLoaded()) return;

    // Add source for heatmap
    if (!map.getSource('location-heatmap')) {
      map.addSource('location-heatmap', {
        type: 'geojson',
        data: {
          type: 'FeatureCollection',
          features: locations.map((loc) => ({
            type: 'Feature',
            properties: { weight: 1 },
            geometry: {
              type: 'Point',
              coordinates: [loc.longitude, loc.latitude],
            },
          })),
        },
      });

      // Add heatmap layer
      map.addLayer({
        id: 'location-heatmap-layer',
        type: 'heatmap',
        source: 'location-heatmap',
        paint: {
          // Increase weight as diameter gets smaller
          'heatmap-weight': ['get', 'weight'],
          
          // Increase intensity as zoom level increases
          'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 0, 1, 9, 3],
          
          // Color ramp for heatmap
          'heatmap-color': [
            'interpolate',
            ['linear'],
            ['heatmap-density'],
            0, 'rgba(33,102,172,0)',
            0.2, 'rgb(103,169,207)',
            0.4, 'rgb(209,229,240)',
            0.6, 'rgb(253,219,199)',
            0.8, 'rgb(239,138,98)',
            1, 'rgb(178,24,43)',
          ],
          
          // Adjust radius based on zoom level
          'heatmap-radius': ['interpolate', ['linear'], ['zoom'], 0, 2, 9, 20],
          
          // Decrease opacity at high zoom levels
          'heatmap-opacity': ['interpolate', ['linear'], ['zoom'], 7, 1, 9, 0.8],
        },
      });

      // Add circle layer for points at high zoom
      map.addLayer({
        id: 'location-points-layer',
        type: 'circle',
        source: 'location-heatmap',
        minzoom: 12,
        paint: {
          'circle-radius': ['interpolate', ['linear'], ['zoom'], 12, 5, 22, 10],
          'circle-color': [
            'interpolate',
            ['linear'],
            ['get', 'weight'],
            0, 'rgba(33,102,172,0.5)',
            1, 'rgba(178,24,43,0.5)',
          ],
          'circle-stroke-color': 'white',
          'circle-stroke-width': 1,
          'circle-opacity': ['interpolate', ['linear'], ['zoom'], 12, 0, 13, 1],
        },
      });
    }

    return () => {
      if (map && map.getLayer('location-heatmap-layer')) {
        map.removeLayer('location-heatmap-layer');
        map.removeLayer('location-points-layer');
        map.removeSource('location-heatmap');
      }
    };
  }, [map]);

  // Update heatmap data when locations change
  useEffect(() => {
    if (!map) return;

    const source = map.getSource('location-heatmap') as mapboxgl.GeoJSONSource;
    if (source) {
      source.setData({
        type: 'FeatureCollection',
        features: locations.map((loc) => ({
          type: 'Feature',
          properties: { weight: 1 },
          geometry: {
            type: 'Point',
            coordinates: [loc.longitude, loc.latitude],
          },
        })),
      });
    }
  }, [map, locations]);

  // Update heatmap visibility
  useEffect(() => {
    if (!map) return;

    const visibility = isEnabled ? 'visible' : 'none';
    
    if (map.getLayer('location-heatmap-layer')) {
      map.setLayoutProperty('location-heatmap-layer', 'visibility', visibility);
    }
    
    if (map.getLayer('location-points-layer')) {
      map.setLayoutProperty('location-points-layer', 'visibility', visibility);
    }
  }, [map, isEnabled]);

  // Update heatmap radius
  useEffect(() => {
    if (!map || !map.getLayer('location-heatmap-layer')) return;

    map.setPaintProperty('location-heatmap-layer', 'heatmap-radius', [
      'interpolate',
      ['linear'],
      ['zoom'],
      0,
      2,
      9,
      radius,
    ]);
  }, [map, radius]);

  // Update heatmap intensity
  useEffect(() => {
    if (!map || !map.getLayer('location-heatmap-layer')) return;

    map.setPaintProperty('location-heatmap-layer', 'heatmap-intensity', [
      'interpolate',
      ['linear'],
      ['zoom'],
      0,
      intensity,
      9,
      intensity * 3,
    ]);
  }, [map, intensity]);

  const handleToggle = () => {
    const newState = !isEnabled;
    setIsEnabled(newState);
    onToggle?.(newState);
  };

  const handleRadiusChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setRadius(parseInt(e.target.value));
  };

  const handleIntensityChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setIntensity(parseFloat(e.target.value));
  };

  if (locations.length === 0) {
    return null;
  }

  return (
    <div className={`${className}`}>
      <div className="flex items-center gap-2">
        {/* Toggle Button */}
        <button
          onClick={handleToggle}
          className={`
            flex items-center gap-2 px-3 py-2 rounded-lg backdrop-blur-md transition-all
            ${
              isEnabled
                ? 'bg-electric-500 text-dark-900 shadow-lg'
                : 'bg-dark-900/80 text-white/80 hover:bg-dark-800/90'
            }
          `}
          title="Toggle Heatmap"
        >
          <Flame className="w-4 h-4" />
          <span className="text-xs font-medium">Heatmap</span>
        </button>

        {/* Settings Button */}
        {isEnabled && (
          <button
            onClick={() => setShowSettings(!showSettings)}
            className="p-2 bg-dark-900/80 hover:bg-dark-800/90 backdrop-blur-md rounded-lg transition-all"
            title="Heatmap Settings"
          >
            <Settings className="w-4 h-4 text-white/80" />
          </button>
        )}
      </div>

      {/* Settings Panel */}
      {isEnabled && showSettings && (
        <div className="absolute top-16 left-4 bg-dark-900/95 backdrop-blur-md rounded-lg p-4 shadow-xl z-10 min-w-[250px]">
          <h3 className="text-white font-medium mb-3 text-sm">Heatmap Settings</h3>
          
          {/* Radius Control */}
          <div className="mb-4">
            <label className="flex items-center justify-between mb-2">
              <span className="text-white/60 text-xs">Radius</span>
              <span className="text-white text-xs font-mono">{radius}px</span>
            </label>
            <input
              type="range"
              min="5"
              max="50"
              value={radius}
              onChange={handleRadiusChange}
              className="w-full h-2 bg-dark-700 rounded-lg appearance-none cursor-pointer"
            />
          </div>

          {/* Intensity Control */}
          <div className="mb-4">
            <label className="flex items-center justify-between mb-2">
              <span className="text-white/60 text-xs">Intensity</span>
              <span className="text-white text-xs font-mono">{intensity.toFixed(1)}x</span>
            </label>
            <input
              type="range"
              min="0.5"
              max="3"
              step="0.1"
              value={intensity}
              onChange={handleIntensityChange}
              className="w-full h-2 bg-dark-700 rounded-lg appearance-none cursor-pointer"
            />
          </div>

          {/* Info */}
          <div className="pt-3 border-t border-white/10">
            <p className="text-white/40 text-xs">
              Showing {locations.length} location{locations.length !== 1 ? 's' : ''}
            </p>
          </div>
        </div>
      )}
    </div>
  );
};
