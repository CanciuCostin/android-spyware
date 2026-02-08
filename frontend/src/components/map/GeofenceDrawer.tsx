import React, { useEffect, useState, useRef } from 'react';
import mapboxgl from 'mapbox-gl';
import MapboxDraw from '@mapbox/mapbox-gl-draw';
import '@mapbox/mapbox-gl-draw/dist/mapbox-gl-draw.css';
import { Pentagon, Save, Trash2, Edit3, X } from 'lucide-react';

interface Geofence {
  id: string;
  name: string;
  type: 'polygon' | 'circle';
  coordinates: number[][];
  radius?: number;
  color?: string;
  alertOnEntry?: boolean;
  alertOnExit?: boolean;
}

interface GeofenceDrawerProps {
  map: mapboxgl.Map | null;
  geofences?: Geofence[];
  onGeofenceCreate?: (geofence: Geofence) => void;
  onGeofenceUpdate?: (geofence: Geofence) => void;
  onGeofenceDelete?: (id: string) => void;
  className?: string;
}

export const GeofenceDrawer: React.FC<GeofenceDrawerProps> = ({
  map,
  geofences = [],
  onGeofenceCreate,
  onGeofenceUpdate,
  onGeofenceDelete,
  className = '',
}) => {
  const [drawMode, setDrawMode] = useState<'off' | 'polygon' | 'edit'>('off');
  const [selectedGeofence, setSelectedGeofence] = useState<Geofence | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    alertOnEntry: true,
    alertOnExit: false,
  });

  const drawRef = useRef<MapboxDraw | null>(null);
  const currentDrawingRef = useRef<any>(null);

  // Initialize Mapbox Draw
  useEffect(() => {
    if (!map || drawRef.current) return;

    const draw = new MapboxDraw({
      displayControlsDefault: false,
      controls: {},
      styles: [
        // Polygon fill
        {
          id: 'gl-draw-polygon-fill',
          type: 'fill',
          filter: ['all', ['==', '$type', 'Polygon']],
          paint: {
            'fill-color': '#10b981',
            'fill-opacity': 0.2,
          },
        },
        // Polygon outline
        {
          id: 'gl-draw-polygon-stroke',
          type: 'line',
          filter: ['all', ['==', '$type', 'Polygon']],
          paint: {
            'line-color': '#10b981',
            'line-width': 3,
          },
        },
        // Polygon vertices
        {
          id: 'gl-draw-polygon-vertices',
          type: 'circle',
          filter: ['all', ['==', 'meta', 'vertex'], ['==', '$type', 'Point']],
          paint: {
            'circle-radius': 6,
            'circle-color': '#10b981',
            'circle-stroke-color': '#fff',
            'circle-stroke-width': 2,
          },
        },
      ],
    });

    map.addControl(draw as any, 'top-right');
    drawRef.current = draw;

    // Event handlers
    map.on('draw.create', handleDrawCreate);
    map.on('draw.update', handleDrawUpdate);
    map.on('draw.delete', handleDrawDelete);

    return () => {
      if (map && drawRef.current) {
        map.off('draw.create', handleDrawCreate);
        map.off('draw.update', handleDrawUpdate);
        map.off('draw.delete', handleDrawDelete);
        map.removeControl(drawRef.current as any);
        drawRef.current = null;
      }
    };
  }, [map]);

  // Load existing geofences
  useEffect(() => {
    if (!map || !drawRef.current) return;

    // Clear existing features
    drawRef.current.deleteAll();

    // Add geofences to map
    geofences.forEach((geofence) => {
      if (geofence.type === 'polygon') {
        drawRef.current!.add({
          type: 'Feature',
          id: geofence.id,
          properties: {
            name: geofence.name,
            alertOnEntry: geofence.alertOnEntry,
            alertOnExit: geofence.alertOnExit,
          },
          geometry: {
            type: 'Polygon',
            coordinates: [geofence.coordinates],
          },
        });
      }
    });
  }, [map, geofences]);

  const handleDrawCreate = (e: any) => {
    if (!e.features || e.features.length === 0) return;
    
    const feature = e.features[0];
    currentDrawingRef.current = feature;
    setShowForm(true);
  };

  const handleDrawUpdate = (e: any) => {
    if (!e.features || e.features.length === 0) return;
    
    const feature = e.features[0];
    const geofence = geofences.find((g) => g.id === feature.id);
    
    if (geofence && onGeofenceUpdate) {
      const updatedGeofence: Geofence = {
        ...geofence,
        coordinates: feature.geometry.coordinates[0],
      };
      onGeofenceUpdate(updatedGeofence);
    }
  };

  const handleDrawDelete = (e: any) => {
    if (!e.features || e.features.length === 0) return;
    
    const feature = e.features[0];
    if (onGeofenceDelete) {
      onGeofenceDelete(feature.id);
    }
  };

  const startDrawing = () => {
    if (!drawRef.current) return;
    
    setDrawMode('polygon');
    drawRef.current.changeMode('draw_polygon');
  };

  const startEditing = () => {
    if (!drawRef.current || !selectedGeofence) return;
    
    setDrawMode('edit');
    drawRef.current.changeMode('direct_select', {
      featureId: selectedGeofence.id,
    });
  };

  const stopDrawing = () => {
    if (!drawRef.current) return;
    
    setDrawMode('off');
    drawRef.current.changeMode('simple_select');
    currentDrawingRef.current = null;
    setShowForm(false);
  };

  const handleSaveGeofence = () => {
    if (!currentDrawingRef.current || !onGeofenceCreate) return;

    const feature = currentDrawingRef.current;
    const geofence: Geofence = {
      id: feature.id || `geofence-${Date.now()}`,
      name: formData.name || `Geofence ${geofences.length + 1}`,
      type: 'polygon',
      coordinates: feature.geometry.coordinates[0],
      alertOnEntry: formData.alertOnEntry,
      alertOnExit: formData.alertOnExit,
    };

    onGeofenceCreate(geofence);
    stopDrawing();
    setFormData({ name: '', alertOnEntry: true, alertOnExit: false });
  };

  const handleDeleteGeofence = (id: string) => {
    if (!drawRef.current || !onGeofenceDelete) return;
    
    drawRef.current.delete(id);
    onGeofenceDelete(id);
    setSelectedGeofence(null);
  };

  const handleFormChange = (field: string, value: any) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  return (
    <div className={`${className}`}>
      <div className="flex items-center gap-2">
        {/* Draw Button */}
        {drawMode === 'off' && (
          <button
            onClick={startDrawing}
            className="flex items-center gap-2 px-3 py-2 bg-electric-500 hover:bg-electric-400 backdrop-blur-md rounded-lg transition-all shadow-lg"
            title="Draw Geofence"
          >
            <Pentagon className="w-4 h-4 text-dark-900" />
            <span className="text-xs font-medium text-dark-900">Draw Geofence</span>
          </button>
        )}

        {/* Cancel Button */}
        {drawMode !== 'off' && (
          <button
            onClick={stopDrawing}
            className="flex items-center gap-2 px-3 py-2 bg-red-500 hover:bg-red-400 backdrop-blur-md rounded-lg transition-all shadow-lg"
            title="Cancel"
          >
            <X className="w-4 h-4 text-white" />
            <span className="text-xs font-medium text-white">Cancel</span>
          </button>
        )}

        {/* Edit Button */}
        {drawMode === 'off' && selectedGeofence && (
          <button
            onClick={startEditing}
            className="p-2 bg-dark-900/80 hover:bg-dark-800/90 backdrop-blur-md rounded-lg transition-all"
            title="Edit Geofence"
          >
            <Edit3 className="w-4 h-4 text-white/80" />
          </button>
        )}

        {/* Geofence Counter */}
        {geofences.length > 0 && drawMode === 'off' && (
          <div className="bg-dark-900/80 backdrop-blur-md px-3 py-2 rounded-lg">
            <span className="text-white/60 text-xs mr-2">Geofences:</span>
            <span className="text-white text-xs font-medium">{geofences.length}</span>
          </div>
        )}
      </div>

      {/* Geofence Form */}
      {showForm && (
        <div className="absolute top-16 left-4 bg-dark-900/95 backdrop-blur-md rounded-lg p-4 shadow-xl z-10 min-w-[300px]">
          <h3 className="text-white font-medium mb-3 text-sm">Save Geofence</h3>
          
          {/* Name Input */}
          <div className="mb-3">
            <label className="block text-white/60 text-xs mb-1">Name</label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => handleFormChange('name', e.target.value)}
              placeholder="Enter geofence name"
              className="w-full px-3 py-2 bg-dark-800 border border-white/10 rounded text-white text-sm focus:outline-none focus:border-electric-500"
            />
          </div>

          {/* Alert Options */}
          <div className="mb-4">
            <label className="flex items-center mb-2">
              <input
                type="checkbox"
                checked={formData.alertOnEntry}
                onChange={(e) => handleFormChange('alertOnEntry', e.target.checked)}
                className="mr-2"
              />
              <span className="text-white/80 text-xs">Alert on entry</span>
            </label>
            
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={formData.alertOnExit}
                onChange={(e) => handleFormChange('alertOnExit', e.target.checked)}
                className="mr-2"
              />
              <span className="text-white/80 text-xs">Alert on exit</span>
            </label>
          </div>

          {/* Buttons */}
          <div className="flex gap-2">
            <button
              onClick={handleSaveGeofence}
              className="flex-1 flex items-center justify-center gap-2 px-3 py-2 bg-electric-500 hover:bg-electric-400 rounded transition-colors"
            >
              <Save className="w-4 h-4 text-dark-900" />
              <span className="text-xs font-medium text-dark-900">Save</span>
            </button>
            
            <button
              onClick={stopDrawing}
              className="px-3 py-2 bg-dark-800 hover:bg-dark-700 rounded transition-colors"
            >
              <span className="text-xs text-white/80">Cancel</span>
            </button>
          </div>
        </div>
      )}

      {/* Geofence List */}
      {geofences.length > 0 && drawMode === 'off' && (
        <div className="absolute top-16 right-4 bg-dark-900/95 backdrop-blur-md rounded-lg p-4 shadow-xl z-10 min-w-[250px] max-h-[400px] overflow-y-auto">
          <h3 className="text-white font-medium mb-3 text-sm">Geofences</h3>
          
          <div className="space-y-2">
            {geofences.map((geofence) => (
              <div
                key={geofence.id}
                className={`
                  p-3 rounded-lg cursor-pointer transition-all
                  ${
                    selectedGeofence?.id === geofence.id
                      ? 'bg-electric-500/20 border border-electric-500'
                      : 'bg-white/5 hover:bg-white/10 border border-transparent'
                  }
                `}
                onClick={() => setSelectedGeofence(geofence)}
              >
                <div className="flex items-start justify-between mb-1">
                  <span className="text-white text-sm font-medium">{geofence.name}</span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleDeleteGeofence(geofence.id);
                    }}
                    className="p-1 hover:bg-red-500/20 rounded transition-colors"
                    title="Delete"
                  >
                    <Trash2 className="w-3 h-3 text-red-400" />
                  </button>
                </div>
                
                <div className="text-xs text-white/60">
                  {geofence.alertOnEntry && <span className="mr-2">📥 Entry</span>}
                  {geofence.alertOnExit && <span>📤 Exit</span>}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
