import { useState, useEffect } from 'react';
import { Panel, PanelGroup, PanelResizeHandle } from 'react-resizable-panels';
import { ChevronLeft, ChevronRight, ChevronUp, ChevronDown } from 'lucide-react';

export interface PanelConfig {
  id: string;
  title: string;
  content: React.ReactNode;
  defaultSize?: number;
  minSize?: number;
  maxSize?: number;
  collapsible?: boolean;
}

interface ResizablePanelsProps {
  direction?: 'horizontal' | 'vertical';
  panels: PanelConfig[];
  storageKey?: string;
}

export const ResizablePanels: React.FC<ResizablePanelsProps> = ({
  direction = 'horizontal',
  panels,
  storageKey = 'resizable-panels-layout',
}) => {
  const [collapsedPanels, setCollapsedPanels] = useState<Set<string>>(new Set());

  useEffect(() => {
    // Load collapsed state from localStorage
    const saved = localStorage.getItem(`${storageKey}-collapsed`);
    if (saved) {
      try {
        setCollapsedPanels(new Set(JSON.parse(saved)));
      } catch (e) {
        // Ignore parse errors
      }
    }
  }, [storageKey]);

  const toggleCollapse = (panelId: string) => {
    setCollapsedPanels((prev) => {
      const next = new Set(prev);
      if (next.has(panelId)) {
        next.delete(panelId);
      } else {
        next.add(panelId);
      }
      
      // Persist to localStorage
      localStorage.setItem(`${storageKey}-collapsed`, JSON.stringify([...next]));
      
      return next;
    });
  };

  const handleLayout = (sizes: number[]) => {
    // Persist panel sizes to localStorage
    localStorage.setItem(storageKey, JSON.stringify(sizes));
  };

  // Load saved layout
  const savedLayout = (() => {
    try {
      const saved = localStorage.getItem(storageKey);
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  })();

  return (
    <PanelGroup
      direction={direction}
      onLayout={handleLayout}
      className="h-full w-full"
    >
      {panels.map((panel, index) => {
        const isCollapsed = collapsedPanels.has(panel.id);
        const CollapseIcon = direction === 'horizontal' 
          ? (index === 0 ? ChevronLeft : ChevronRight)
          : (index === 0 ? ChevronUp : ChevronDown);
        const ExpandIcon = direction === 'horizontal'
          ? (index === 0 ? ChevronRight : ChevronLeft)
          : (index === 0 ? ChevronDown : ChevronUp);

        return (
          <>
            <Panel
              key={panel.id}
              id={panel.id}
              defaultSize={savedLayout?.[index] || panel.defaultSize || 50}
              minSize={isCollapsed ? 0 : panel.minSize || 20}
              maxSize={panel.maxSize || 80}
              collapsible={panel.collapsible}
              className="relative"
            >
              <div className="h-full flex flex-col bg-gray-900">
                {/* Panel Header */}
                <div className="flex items-center justify-between bg-gray-800 px-4 py-2 border-b border-gray-700">
                  <h3 className="text-white font-medium">{panel.title}</h3>
                  {panel.collapsible && (
                    <button
                      onClick={() => toggleCollapse(panel.id)}
                      className="p-1 hover:bg-gray-700 rounded transition-colors"
                      title={isCollapsed ? 'Expand' : 'Collapse'}
                    >
                      {isCollapsed ? (
                        <ExpandIcon size={16} className="text-gray-400" />
                      ) : (
                        <CollapseIcon size={16} className="text-gray-400" />
                      )}
                    </button>
                  )}
                </div>

                {/* Panel Content */}
                {!isCollapsed && (
                  <div className="flex-1 overflow-auto p-4">
                    {panel.content}
                  </div>
                )}
              </div>
            </Panel>

            {/* Resize Handle (not after last panel) */}
            {index < panels.length - 1 && (
              <PanelResizeHandle
                className={`
                  ${direction === 'horizontal' ? 'w-1' : 'h-1'}
                  bg-gray-700 hover:bg-blue-500 transition-colors
                  relative group
                `}
              >
                <div className={`
                  absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2
                  bg-gray-800 rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity
                `}>
                  {direction === 'horizontal' ? (
                    <div className="w-1 h-8 bg-gray-600 rounded" />
                  ) : (
                    <div className="h-1 w-8 bg-gray-600 rounded" />
                  )}
                </div>
              </PanelResizeHandle>
            )}
          </>
        );
      })}
    </PanelGroup>
  );
};
