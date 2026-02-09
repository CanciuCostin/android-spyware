import { useState } from 'react';
import { X } from 'lucide-react';

export interface Tab {
  id: string;
  label: string;
  icon?: React.ReactNode;
}

interface TabSystemProps {
  tabs: Tab[];
  activeTab: string;
  onTabChange: (tabId: string) => void;
  onTabClose?: (tabId: string) => void;
  maxVisibleTabs?: number;
}

export function TabSystem({
  tabs,
  activeTab,
  onTabChange,
  onTabClose,
  maxVisibleTabs = 8,
}: TabSystemProps) {
  const [hoveredTab, setHoveredTab] = useState<string | null>(null);

  const visibleTabs = tabs.slice(0, maxVisibleTabs);
  const overflowCount = Math.max(0, tabs.length - maxVisibleTabs);

  const handleTabClose = (e: React.MouseEvent, tabId: string) => {
    e.stopPropagation();
    onTabClose?.(tabId);
  };

  return (
    <div className="border-b border-gray-200 bg-white">
      <div className="flex items-center overflow-x-auto scrollbar-thin">
        {visibleTabs.map((tab) => {
          const isActive = tab.id === activeTab;
          const isHovered = tab.id === hoveredTab;

          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              onMouseEnter={() => setHoveredTab(tab.id)}
              onMouseLeave={() => setHoveredTab(null)}
              className={`
                relative flex items-center gap-2 px-4 py-3 border-r border-gray-200
                transition-all duration-200 whitespace-nowrap
                ${isActive
                  ? 'bg-white text-cyan-600 border-b-2 border-cyan-500'
                  : 'bg-gray-50 text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                }
                ${onTabClose ? 'pr-8' : ''}
              `}
            >
              {tab.icon && <span className="flex-shrink-0">{tab.icon}</span>}
              <span className="text-sm font-medium max-w-[150px] truncate">
                {tab.label}
              </span>

              {onTabClose && tabs.length > 1 && (
                <button
                  onClick={(e) => handleTabClose(e, tab.id)}
                  className={`
                    absolute right-2 p-1 rounded-full transition-all
                    ${isHovered || isActive
                      ? 'opacity-100 hover:bg-gray-200'
                      : 'opacity-0'
                    }
                  `}
                  aria-label={`Close ${tab.label}`}
                >
                  <X size={14} />
                </button>
              )}
            </button>
          );
        })}

        {overflowCount > 0 && (
          <div className="flex items-center px-3 py-3 text-xs text-gray-500 bg-gray-50">
            +{overflowCount} more
          </div>
        )}
      </div>
    </div>
  );
}
