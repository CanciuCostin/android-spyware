import React, { useState, useEffect, useRef, useMemo } from 'react';
import mapboxgl from 'mapbox-gl';
import { Play, Pause, SkipBack, SkipForward, Calendar } from 'lucide-react';

interface LocationPoint {
  id: string;
  latitude: number;
  longitude: number;
  timestamp: string;
  accuracy?: number;
  speed?: number;
}

interface LocationHistoryProps {
  locations: LocationPoint[];
  map: mapboxgl.Map | null;
  className?: string;
}

export const LocationHistory: React.FC<LocationHistoryProps> = ({
  locations,
  map,
  className = '',
}) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [playbackSpeed, setPlaybackSpeed] = useState(1); // 1x, 2x, 4x
  const [dateRange, setDateRange] = useState<[Date | null, Date | null]>([null, null]);
  
  const animationRef = useRef<number | null>(null);
  const markerRef = useRef<mapboxgl.Marker | null>(null);
  const pathSourceRef = useRef<boolean>(false);

  // Filter locations by date range
  const filteredLocations = useMemo(() => {
    if (!dateRange[0] || !dateRange[1]) return locations;
    const start = dateRange[0].getTime();
    const end = dateRange[1].getTime();
    return locations.filter((loc) => {
      const time = new Date(loc.timestamp).getTime();
      return time >= start && time <= end;
    });
  }, [locations, dateRange]);

  // Sort locations by timestamp
  const sortedLocations = useMemo(() => {
    return [...filteredLocations].sort(
      (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
    );
  }, [filteredLocations]);

  // Initialize path layer
  useEffect(() => {
    if (!map || !map.isStyleLoaded()) return;

    // Add source for path line
    if (!map.getSource('location-path')) {
      map.addSource('location-path', {
        type: 'geojson',
        data: {
          type: 'Feature',
          properties: {},
          geometry: {
            type: 'LineString',
            coordinates: [],
          },
        },
      });

      // Add layer for path
      map.addLayer({
        id: 'location-path-layer',
        type: 'line',
        source: 'location-path',
        paint: {
          'line-color': '#10b981',
          'line-width': 3,
          'line-opacity': 0.8,
        },
      });

      // Add layer for path outline
      map.addLayer({
        id: 'location-path-outline',
        type: 'line',
        source: 'location-path',
        paint: {
          'line-color': '#059669',
          'line-width': 5,
          'line-opacity': 0.4,
        },
      });

      pathSourceRef.current = true;
    }

    return () => {
      if (map && map.getLayer('location-path-layer')) {
        map.removeLayer('location-path-layer');
        map.removeLayer('location-path-outline');
        map.removeSource('location-path');
        pathSourceRef.current = false;
      }
    };
  }, [map]);

  // Update path when locations change
  useEffect(() => {
    if (!map || !pathSourceRef.current || sortedLocations.length === 0) return;

    const coordinates = sortedLocations
      .slice(0, currentIndex + 1)
      .map((loc) => [loc.longitude, loc.latitude]);

    const source = map.getSource('location-path') as mapboxgl.GeoJSONSource;
    if (source) {
      source.setData({
        type: 'Feature',
        properties: {},
        geometry: {
          type: 'LineString',
          coordinates,
        },
      });
    }
  }, [map, sortedLocations, currentIndex]);

  // Update marker position
  useEffect(() => {
    if (!map || sortedLocations.length === 0) return;

    const currentLocation = sortedLocations[currentIndex];
    if (!currentLocation) return;

    if (!markerRef.current) {
      // Create animated marker
      const el = createAnimatedMarker();
      markerRef.current = new mapboxgl.Marker({ element: el })
        .setLngLat([currentLocation.longitude, currentLocation.latitude])
        .addTo(map);

      const popup = new mapboxgl.Popup({ offset: 25 });
      markerRef.current.setPopup(popup);
    }

    // Update marker position with animation
    markerRef.current.setLngLat([currentLocation.longitude, currentLocation.latitude]);

    // Update popup content
    const popup = markerRef.current.getPopup();
    popup.setHTML(`
      <div class="p-2">
        <p class="text-sm font-medium mb-1">${new Date(currentLocation.timestamp).toLocaleString()}</p>
        <p class="text-xs text-gray-600">Lat: ${currentLocation.latitude.toFixed(6)}</p>
        <p class="text-xs text-gray-600">Lng: ${currentLocation.longitude.toFixed(6)}</p>
        ${currentLocation.accuracy ? `<p class="text-xs text-gray-500">Accuracy: ±${currentLocation.accuracy}m</p>` : ''}
        ${currentLocation.speed ? `<p class="text-xs text-gray-500">Speed: ${currentLocation.speed.toFixed(1)} m/s</p>` : ''}
      </div>
    `);

    // Center map on current location
    if (isPlaying) {
      map.panTo([currentLocation.longitude, currentLocation.latitude], {
        duration: 500,
      });
    }

    return () => {
      if (markerRef.current) {
        markerRef.current.remove();
        markerRef.current = null;
      }
    };
  }, [map, sortedLocations, currentIndex, isPlaying]);

  // Playback animation
  useEffect(() => {
    if (!isPlaying || currentIndex >= sortedLocations.length - 1) {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
        animationRef.current = null;
      }
      if (currentIndex >= sortedLocations.length - 1) {
        setIsPlaying(false);
      }
      return;
    }

    const baseInterval = 1000; // 1 second base
    const interval = baseInterval / playbackSpeed;
    let lastTime = Date.now();

    const animate = () => {
      const now = Date.now();
      if (now - lastTime >= interval) {
        setCurrentIndex((prev) => Math.min(prev + 1, sortedLocations.length - 1));
        lastTime = now;
      }
      animationRef.current = requestAnimationFrame(animate);
    };

    animationRef.current = requestAnimationFrame(animate);

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
        animationRef.current = null;
      }
    };
  }, [isPlaying, currentIndex, sortedLocations.length, playbackSpeed]);

  const handlePlayPause = () => {
    setIsPlaying(!isPlaying);
  };

  const handleReset = () => {
    setIsPlaying(false);
    setCurrentIndex(0);
  };

  const handleSkipForward = () => {
    setCurrentIndex((prev) => Math.min(prev + 10, sortedLocations.length - 1));
  };

  const handleSpeedChange = () => {
    const speeds = [1, 2, 4];
    const currentSpeedIndex = speeds.indexOf(playbackSpeed);
    const nextSpeed = speeds[(currentSpeedIndex + 1) % speeds.length];
    setPlaybackSpeed(nextSpeed);
  };

  const handleSliderChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const index = parseInt(e.target.value);
    setCurrentIndex(index);
    setIsPlaying(false);
  };

  if (sortedLocations.length === 0) {
    return (
      <div className={`bg-dark-800/50 backdrop-blur-sm rounded-lg p-4 ${className}`}>
        <p className="text-white/40 text-sm text-center">No location history available</p>
      </div>
    );
  }

  const currentLocation = sortedLocations[currentIndex];
  const progress = (currentIndex / (sortedLocations.length - 1)) * 100;

  return (
    <div className={`bg-dark-900/90 backdrop-blur-md rounded-lg p-4 ${className}`}>
      {/* Timeline Slider */}
      <div className="mb-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-white/60 text-xs">
            {currentIndex + 1} / {sortedLocations.length}
          </span>
          <span className="text-white/80 text-xs font-mono">
            {new Date(currentLocation.timestamp).toLocaleString()}
          </span>
        </div>
        
        <div className="relative">
          <input
            type="range"
            min="0"
            max={sortedLocations.length - 1}
            value={currentIndex}
            onChange={handleSliderChange}
            className="w-full h-2 bg-dark-700 rounded-lg appearance-none cursor-pointer"
            style={{
              background: `linear-gradient(to right, #10b981 0%, #10b981 ${progress}%, #374151 ${progress}%, #374151 100%)`,
            }}
          />
        </div>
      </div>

      {/* Controls */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <button
            onClick={handleReset}
            className="p-2 bg-dark-800 hover:bg-dark-700 rounded-lg transition-colors"
            title="Reset"
          >
            <SkipBack className="w-4 h-4 text-white" />
          </button>
          
          <button
            onClick={handlePlayPause}
            className="p-2 bg-electric-500 hover:bg-electric-400 rounded-lg transition-colors"
            title={isPlaying ? 'Pause' : 'Play'}
          >
            {isPlaying ? (
              <Pause className="w-4 h-4 text-dark-900" />
            ) : (
              <Play className="w-4 h-4 text-dark-900" />
            )}
          </button>

          <button
            onClick={handleSkipForward}
            className="p-2 bg-dark-800 hover:bg-dark-700 rounded-lg transition-colors"
            title="Skip Forward"
          >
            <SkipForward className="w-4 h-4 text-white" />
          </button>

          <button
            onClick={handleSpeedChange}
            className="px-3 py-2 bg-dark-800 hover:bg-dark-700 rounded-lg transition-colors"
            title="Playback Speed"
          >
            <span className="text-white text-xs font-medium">{playbackSpeed}x</span>
          </button>
        </div>

        {/* Stats */}
        <div className="text-right">
          <p className="text-white/60 text-xs">
            Duration: {formatDuration(sortedLocations)}
          </p>
        </div>
      </div>
    </div>
  );
};

function createAnimatedMarker(): HTMLDivElement {
  const el = document.createElement('div');
  el.className = 'relative';
  el.innerHTML = `
    <div class="absolute inset-0 w-8 h-8 bg-green-500 rounded-full animate-ping opacity-75"></div>
    <div class="relative w-8 h-8 bg-green-500 rounded-full border-4 border-white shadow-lg flex items-center justify-center">
      <div class="w-3 h-3 bg-white rounded-full"></div>
    </div>
  `;
  return el;
}

function formatDuration(locations: LocationPoint[]): string {
  if (locations.length < 2) return '0m';
  
  const start = new Date(locations[0].timestamp).getTime();
  const end = new Date(locations[locations.length - 1].timestamp).getTime();
  const diff = end - start;
  
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
}
