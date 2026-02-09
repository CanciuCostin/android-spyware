import { useState, useCallback } from 'react';
import GridLayout, { Layout } from 'react-grid-layout';
import { GripVertical, X, Plus } from 'lucide-react';
import 'react-grid-layout/css/styles.css';
import './grid-layout.css';

export interface Widget {
  id: string;
  title: string;
  component: React.ReactNode;
  defaultSize?: { w: number; h: number };
  minSize?: { w: number; h: number };
}

interface WidgetGridProps {
  widgets: Widget[];
  layout?: Layout[];
  onLayoutChange?: (layout: Layout[]) => void;
  editable?: boolean;
  cols?: number;
  rowHeight?: number;
}

const defaultLayouts: Record<string, Layout[]> = {
  compact: [
    { i: 'device-status', x: 0, y: 0, w: 4, h: 2 },
    { i: 'active-sessions', x: 4, y: 0, w: 4, h: 2 },
    { i: 'recent-activity', x: 8, y: 0, w: 4, h: 2 },
  ],
  detailed: [
    { i: 'device-status', x: 0, y: 0, w: 6, h: 4 },
    { i: 'active-sessions', x: 6, y: 0, w: 6, h: 4 },
    { i: 'recent-activity', x: 0, y: 4, w: 12, h: 3 },
  ],
  monitoring: [
    { i: 'device-status', x: 0, y: 0, w: 3, h: 3 },
    { i: 'active-sessions', x: 3, y: 0, w: 3, h: 3 },
    { i: 'recent-activity', x: 6, y: 0, w: 6, h: 3 },
    { i: 'system-health', x: 0, y: 3, w: 12, h: 2 },
  ],
};

export const WidgetGrid: React.FC<WidgetGridProps> = ({
  widgets,
  layout: initialLayout,
  onLayoutChange,
  editable = true,
  cols = 12,
  rowHeight = 80,
}) => {
  const [activeWidgets, setActiveWidgets] = useState<Widget[]>(widgets);
  const [layout, setLayout] = useState<Layout[]>(
    initialLayout ||
      widgets.map((widget, idx) => ({
        i: widget.id,
        x: (idx % 4) * 3,
        y: Math.floor(idx / 4) * 2,
        w: widget.defaultSize?.w || 3,
        h: widget.defaultSize?.h || 2,
        minW: widget.minSize?.w,
        minH: widget.minSize?.h,
      }))
  );

  const handleLayoutChange = useCallback(
    (newLayout: Layout[]) => {
      setLayout(newLayout);
      onLayoutChange?.(newLayout);
      
      // Persist to localStorage
      localStorage.setItem('widgetGridLayout', JSON.stringify(newLayout));
    },
    [onLayoutChange]
  );

  const removeWidget = useCallback((widgetId: string) => {
    setActiveWidgets((prev) => prev.filter((w) => w.id !== widgetId));
    setLayout((prev) => prev.filter((l) => l.i !== widgetId));
  }, []);

  const addWidget = useCallback((widget: Widget) => {
    setActiveWidgets((prev) => [...prev, widget]);
    const newLayout: Layout = {
      i: widget.id,
      x: 0,
      y: Infinity, // Places at bottom
      w: widget.defaultSize?.w || 3,
      h: widget.defaultSize?.h || 2,
      minW: widget.minSize?.w,
      minH: widget.minSize?.h,
    };
    setLayout((prev) => [...prev, newLayout]);
  }, []);

  const applyPreset = useCallback((preset: string) => {
    const presetLayout = defaultLayouts[preset];
    if (presetLayout) {
      setLayout(presetLayout);
      onLayoutChange?.(presetLayout);
    }
  }, [onLayoutChange]);

  const availableWidgets = widgets.filter(
    (w) => !activeWidgets.find((aw) => aw.id === w.id)
  );

  return (
    <div className="relative">
      {/* Control Bar */}
      {editable && (
        <div className="mb-4 flex items-center justify-between bg-gray-800 p-3 rounded-lg">
          <div className="flex gap-2">
            <button
              onClick={() => applyPreset('compact')}
              className="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-white text-sm"
            >
              Compact
            </button>
            <button
              onClick={() => applyPreset('detailed')}
              className="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-white text-sm"
            >
              Detailed
            </button>
            <button
              onClick={() => applyPreset('monitoring')}
              className="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-white text-sm"
            >
              Monitoring
            </button>
          </div>
          
          {availableWidgets.length > 0 && (
            <div className="relative group">
              <button className="px-3 py-1 bg-blue-600 hover:bg-blue-700 rounded text-white text-sm flex items-center gap-1">
                <Plus size={16} />
                Add Widget
              </button>
              <div className="absolute right-0 mt-2 w-48 bg-gray-800 rounded-lg shadow-lg hidden group-hover:block z-50">
                {availableWidgets.map((widget) => (
                  <button
                    key={widget.id}
                    onClick={() => addWidget(widget)}
                    className="w-full px-4 py-2 text-left text-white hover:bg-gray-700 first:rounded-t-lg last:rounded-b-lg"
                  >
                    {widget.title}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Grid */}
      <GridLayout
        className="layout"
        layout={layout}
        cols={cols}
        rowHeight={rowHeight}
        width={1200}
        isDraggable={editable}
        isResizable={editable}
        onLayoutChange={handleLayoutChange}
        draggableHandle=".drag-handle"
      >
        {activeWidgets.map((widget) => (
          <div
            key={widget.id}
            className="bg-gray-800 rounded-lg border border-gray-700 overflow-hidden"
          >
            <div className="flex items-center justify-between bg-gray-900 px-3 py-2 border-b border-gray-700">
              <div className="flex items-center gap-2">
                {editable && (
                  <div className="drag-handle cursor-move">
                    <GripVertical size={16} className="text-gray-400" />
                  </div>
                )}
                <span className="text-white text-sm font-medium">{widget.title}</span>
              </div>
              {editable && (
                <button
                  onClick={() => removeWidget(widget.id)}
                  className="p-1 hover:bg-gray-700 rounded transition-colors"
                >
                  <X size={14} className="text-gray-400" />
                </button>
              )}
            </div>
            <div className="p-4 h-[calc(100%-40px)] overflow-auto">
              {widget.component}
            </div>
          </div>
        ))}
      </GridLayout>
    </div>
  );
};
