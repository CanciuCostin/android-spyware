import React, { useState, useMemo } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '../ui';
import { MapPin, Calendar, Clock, Navigation, Download, ChevronDown, ChevronUp } from 'lucide-react';

interface LocationPoint {
  id: string;
  latitude: number;
  longitude: number;
  timestamp: string;
  accuracy?: number;
  speed?: number;
  altitude?: number;
}

interface LocationListViewProps {
  locations: LocationPoint[];
  onLocationClick?: (location: LocationPoint) => void;
  selectedLocationId?: string;
  className?: string;
}

type SortField = 'timestamp' | 'accuracy' | 'speed';
type SortOrder = 'asc' | 'desc';

export const LocationListView: React.FC<LocationListViewProps> = ({
  locations,
  onLocationClick,
  selectedLocationId,
  className = '',
}) => {
  const [sortField, setSortField] = useState<SortField>('timestamp');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');
  const [expandedId, setExpandedId] = useState<string | null>(null);

  // Sort locations
  const sortedLocations = useMemo(() => {
    return [...locations].sort((a, b) => {
      let aVal: any;
      let bVal: any;

      switch (sortField) {
        case 'timestamp':
          aVal = new Date(a.timestamp).getTime();
          bVal = new Date(b.timestamp).getTime();
          break;
        case 'accuracy':
          aVal = a.accuracy || 0;
          bVal = b.accuracy || 0;
          break;
        case 'speed':
          aVal = a.speed || 0;
          bVal = b.speed || 0;
          break;
      }

      if (sortOrder === 'asc') {
        return aVal - bVal;
      } else {
        return bVal - aVal;
      }
    });
  }, [locations, sortField, sortOrder]);

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortOrder('desc');
    }
  };

  const exportToGPX = () => {
    const gpx = generateGPX(locations);
    downloadFile(gpx, 'locations.gpx', 'application/gpx+xml');
  };

  const exportToKML = () => {
    const kml = generateKML(locations);
    downloadFile(kml, 'locations.kml', 'application/vnd.google-earth.kml+xml');
  };

  const exportToJSON = () => {
    const json = JSON.stringify(locations, null, 2);
    downloadFile(json, 'locations.json', 'application/json');
  };

  if (locations.length === 0) {
    return (
      <Card variant="glass" className={className}>
        <CardContent className="py-12">
          <div className="text-center">
            <MapPin className="w-12 h-12 text-white/20 mx-auto mb-3" />
            <p className="text-white/40 text-sm">No location data available</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card variant="glass" className={className}>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <MapPin className="w-5 h-5" />
            Location History ({sortedLocations.length})
          </CardTitle>
          
          <div className="flex items-center gap-2">
            <button
              onClick={exportToGPX}
              className="px-3 py-1.5 bg-dark-800 hover:bg-dark-700 rounded text-xs text-white/80 transition-colors"
              title="Export to GPX"
            >
              GPX
            </button>
            <button
              onClick={exportToKML}
              className="px-3 py-1.5 bg-dark-800 hover:bg-dark-700 rounded text-xs text-white/80 transition-colors"
              title="Export to KML"
            >
              KML
            </button>
            <button
              onClick={exportToJSON}
              className="px-3 py-1.5 bg-electric-500 hover:bg-electric-400 rounded text-xs text-dark-900 font-medium transition-colors flex items-center gap-1"
              title="Export to JSON"
            >
              <Download className="w-3 h-3" />
              Export
            </button>
          </div>
        </div>
      </CardHeader>

      <CardContent>
        {/* Table Header */}
        <div className="grid grid-cols-12 gap-4 px-4 py-2 bg-dark-800/50 rounded-t-lg text-xs text-white/60 font-medium">
          <div
            className="col-span-3 flex items-center gap-1 cursor-pointer hover:text-white/80"
            onClick={() => handleSort('timestamp')}
          >
            <Clock className="w-3 h-3" />
            <span>Timestamp</span>
            {sortField === 'timestamp' && (
              sortOrder === 'desc' ? <ChevronDown className="w-3 h-3" /> : <ChevronUp className="w-3 h-3" />
            )}
          </div>
          <div className="col-span-3">Coordinates</div>
          <div
            className="col-span-2 flex items-center gap-1 cursor-pointer hover:text-white/80"
            onClick={() => handleSort('accuracy')}
          >
            <span>Accuracy</span>
            {sortField === 'accuracy' && (
              sortOrder === 'desc' ? <ChevronDown className="w-3 h-3" /> : <ChevronUp className="w-3 h-3" />
            )}
          </div>
          <div
            className="col-span-2 flex items-center gap-1 cursor-pointer hover:text-white/80"
            onClick={() => handleSort('speed')}
          >
            <Navigation className="w-3 h-3" />
            <span>Speed</span>
            {sortField === 'speed' && (
              sortOrder === 'desc' ? <ChevronDown className="w-3 h-3" /> : <ChevronUp className="w-3 h-3" />
            )}
          </div>
          <div className="col-span-2">Actions</div>
        </div>

        {/* Table Body */}
        <div className="max-h-[400px] overflow-y-auto">
          {sortedLocations.map((location, index) => (
            <div
              key={location.id}
              className={`
                grid grid-cols-12 gap-4 px-4 py-3 border-b border-white/5 transition-all
                ${selectedLocationId === location.id ? 'bg-electric-500/10' : 'hover:bg-white/5'}
                ${index === sortedLocations.length - 1 ? 'rounded-b-lg border-b-0' : ''}
              `}
            >
              <div className="col-span-3 text-sm">
                <div className="text-white font-medium">
                  {new Date(location.timestamp).toLocaleTimeString()}
                </div>
                <div className="text-white/40 text-xs">
                  {new Date(location.timestamp).toLocaleDateString()}
                </div>
              </div>
              
              <div className="col-span-3 text-sm font-mono">
                <div className="text-white/80">{location.latitude.toFixed(6)}</div>
                <div className="text-white/80">{location.longitude.toFixed(6)}</div>
              </div>
              
              <div className="col-span-2 text-sm">
                <span className="text-white/60">
                  {location.accuracy ? `±${location.accuracy}m` : 'N/A'}
                </span>
              </div>
              
              <div className="col-span-2 text-sm">
                <span className="text-white/60">
                  {location.speed ? `${location.speed.toFixed(1)} m/s` : 'N/A'}
                </span>
              </div>
              
              <div className="col-span-2 flex items-center gap-2">
                <button
                  onClick={() => onLocationClick?.(location)}
                  className="px-2 py-1 bg-electric-500/20 hover:bg-electric-500/30 border border-electric-500/50 rounded text-xs text-electric-400 transition-colors"
                >
                  View
                </button>
                {expandedId === location.id ? (
                  <button
                    onClick={() => setExpandedId(null)}
                    className="p-1 hover:bg-white/10 rounded transition-colors"
                  >
                    <ChevronUp className="w-4 h-4 text-white/60" />
                  </button>
                ) : (
                  <button
                    onClick={() => setExpandedId(location.id)}
                    className="p-1 hover:bg-white/10 rounded transition-colors"
                  >
                    <ChevronDown className="w-4 h-4 text-white/60" />
                  </button>
                )}
              </div>

              {/* Expanded Details */}
              {expandedId === location.id && (
                <div className="col-span-12 mt-2 p-3 bg-dark-800/30 rounded text-xs">
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <span className="text-white/40">Latitude:</span>
                      <span className="text-white ml-2 font-mono">{location.latitude}</span>
                    </div>
                    <div>
                      <span className="text-white/40">Longitude:</span>
                      <span className="text-white ml-2 font-mono">{location.longitude}</span>
                    </div>
                    {location.altitude !== undefined && (
                      <div>
                        <span className="text-white/40">Altitude:</span>
                        <span className="text-white ml-2">{location.altitude}m</span>
                      </div>
                    )}
                    {location.accuracy !== undefined && (
                      <div>
                        <span className="text-white/40">Accuracy:</span>
                        <span className="text-white ml-2">±{location.accuracy}m</span>
                      </div>
                    )}
                    {location.speed !== undefined && (
                      <div>
                        <span className="text-white/40">Speed:</span>
                        <span className="text-white ml-2">{location.speed.toFixed(2)} m/s</span>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
};

// Helper functions
function downloadFile(content: string, filename: string, mimeType: string) {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

function generateGPX(locations: LocationPoint[]): string {
  const points = locations
    .map(
      (loc) => `
    <trkpt lat="${loc.latitude}" lon="${loc.longitude}">
      <time>${loc.timestamp}</time>
      ${loc.altitude ? `<ele>${loc.altitude}</ele>` : ''}
    </trkpt>`
    )
    .join('');

  return `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="EagleSpy">
  <trk>
    <name>Location History</name>
    <trkseg>${points}
    </trkseg>
  </trk>
</gpx>`;
}

function generateKML(locations: LocationPoint[]): string {
  const coordinates = locations
    .map((loc) => `${loc.longitude},${loc.latitude},${loc.altitude || 0}`)
    .join('\n        ');

  return `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Location History</name>
    <Placemark>
      <name>Path</name>
      <LineString>
        <coordinates>
        ${coordinates}
        </coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>`;
}
