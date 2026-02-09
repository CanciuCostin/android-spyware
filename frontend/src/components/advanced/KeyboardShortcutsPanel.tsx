import { useState, useMemo } from 'react';
import { Search, X, Keyboard } from 'lucide-react';

export interface KeyboardShortcut {
  category: string;
  key: string;
  description: string;
  action?: () => void;
}

interface KeyboardShortcutsPanelProps {
  isOpen: boolean;
  onClose: () => void;
  shortcuts: KeyboardShortcut[];
  mode?: 'modal' | 'panel';
}

const KeySymbol: React.FC<{ symbol: string }> = ({ symbol }) => {
  const getDisplaySymbol = (key: string) => {
    const symbols: Record<string, string> = {
      'Cmd': '⌘',
      'Ctrl': '⌃',
      'Alt': '⌥',
      'Shift': '⇧',
      'Enter': '↵',
      'Backspace': '⌫',
      'Delete': '⌦',
      'Escape': '⎋',
      'Tab': '⇥',
      'Space': '␣',
      'Up': '↑',
      'Down': '↓',
      'Left': '←',
      'Right': '→',
    };
    return symbols[key] || key;
  };

  const keys = symbol.split('+').map((k) => k.trim());

  return (
    <div className="flex items-center gap-1">
      {keys.map((key, idx) => (
        <span key={idx} className="flex items-center gap-1">
          <kbd className="px-2 py-1 bg-gray-700 border border-gray-600 rounded text-xs font-mono text-white">
            {getDisplaySymbol(key)}
          </kbd>
          {idx < keys.length - 1 && <span className="text-gray-500">+</span>}
        </span>
      ))}
    </div>
  );
};

export const KeyboardShortcutsPanel: React.FC<KeyboardShortcutsPanelProps> = ({
  isOpen,
  onClose,
  shortcuts,
  mode = 'modal',
}) => {
  const [searchQuery, setSearchQuery] = useState('');

  const filteredShortcuts = useMemo(() => {
    if (!searchQuery) return shortcuts;

    const query = searchQuery.toLowerCase();
    return shortcuts.filter(
      (shortcut) =>
        shortcut.key.toLowerCase().includes(query) ||
        shortcut.description.toLowerCase().includes(query) ||
        shortcut.category.toLowerCase().includes(query)
    );
  }, [shortcuts, searchQuery]);

  const groupedShortcuts = useMemo(() => {
    const groups: Record<string, KeyboardShortcut[]> = {};
    filteredShortcuts.forEach((shortcut) => {
      if (!groups[shortcut.category]) {
        groups[shortcut.category] = [];
      }
      groups[shortcut.category].push(shortcut);
    });
    return groups;
  }, [filteredShortcuts]);

  if (!isOpen) return null;

  const content = (
    <div className={`bg-gray-900 ${mode === 'modal' ? 'rounded-lg' : ''} flex flex-col h-full`}>
      {/* Header */}
      <div className="flex items-center justify-between bg-gray-800 px-4 py-3 border-b border-gray-700">
        <div className="flex items-center gap-2">
          <Keyboard size={20} className="text-blue-400" />
          <h2 className="text-white text-lg font-semibold">Keyboard Shortcuts</h2>
        </div>
        <button
          onClick={onClose}
          className="p-1 hover:bg-gray-700 rounded transition-colors"
          title="Close"
        >
          <X size={20} className="text-gray-400" />
        </button>
      </div>

      {/* Search */}
      <div className="p-4 border-b border-gray-700">
        <div className="relative">
          <Search size={18} className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search shortcuts..."
            className="w-full pl-10 pr-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-blue-500"
          />
        </div>
      </div>

      {/* Shortcuts List */}
      <div className="flex-1 overflow-auto p-4">
        {Object.keys(groupedShortcuts).length === 0 ? (
          <div className="text-center text-gray-500 py-8">
            No shortcuts found matching "{searchQuery}"
          </div>
        ) : (
          <div className="space-y-6">
            {Object.entries(groupedShortcuts).map(([category, categoryShortcuts]) => (
              <div key={category}>
                <h3 className="text-gray-400 text-sm font-semibold uppercase mb-3">
                  {category}
                </h3>
                <div className="space-y-2">
                  {categoryShortcuts.map((shortcut, idx) => (
                    <div
                      key={idx}
                      className="flex items-center justify-between p-3 bg-gray-800 rounded-lg hover:bg-gray-750 transition-colors"
                    >
                      <span className="text-white text-sm">{shortcut.description}</span>
                      <KeySymbol symbol={shortcut.key} />
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Footer */}
      <div className="px-4 py-3 bg-gray-800 border-t border-gray-700 text-center text-gray-500 text-xs">
        Press <kbd className="px-1 py-0.5 bg-gray-700 border border-gray-600 rounded text-xs">?</kbd> or{' '}
        <kbd className="px-1 py-0.5 bg-gray-700 border border-gray-600 rounded text-xs">Esc</kbd> to close
      </div>
    </div>
  );

  if (mode === 'modal') {
    return (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[10000]">
        <div className="w-full max-w-3xl max-h-[80vh] shadow-2xl">
          {content}
        </div>
      </div>
    );
  }

  return (
    <div className="fixed right-0 top-0 h-full w-96 shadow-2xl z-[10000]">
      {content}
    </div>
  );
};

// Default shortcuts for EagleSpy
export const defaultShortcuts: KeyboardShortcut[] = [
  // Navigation
  { category: 'Navigation', key: 'Cmd+K', description: 'Open Command Palette' },
  { category: 'Navigation', key: 'Cmd+D', description: 'Jump to Devices' },
  { category: 'Navigation', key: 'Cmd+H', description: 'Go to Dashboard' },
  { category: 'Navigation', key: 'Cmd+M', description: 'Open Map View' },
  { category: 'Navigation', key: 'Cmd+/', description: 'Toggle Sidebar' },

  // Devices
  { category: 'Devices', key: 'Cmd+F', description: 'Search Devices' },
  { category: 'Devices', key: 'Cmd+R', description: 'Refresh Device List' },
  { category: 'Devices', key: 'Cmd+S', description: 'Toggle Split Screen' },
  { category: 'Devices', key: 'Cmd+P', description: 'Open PiP Panel' },

  // Actions
  { category: 'Actions', key: 'Cmd+Enter', description: 'Execute Command' },
  { category: 'Actions', key: 'Cmd+N', description: 'New Terminal Session' },
  { category: 'Actions', key: 'Cmd+T', description: 'Take Screenshot' },
  { category: 'Actions', key: 'Cmd+L', description: 'View Logs' },

  // View
  { category: 'View', key: 'Cmd+B', description: 'Toggle Theme' },
  { category: 'View', key: 'Cmd+Plus', description: 'Zoom In' },
  { category: 'View', key: 'Cmd+Minus', description: 'Zoom Out' },
  { category: 'View', key: 'Cmd+0', description: 'Reset Zoom' },

  // General
  { category: 'General', key: 'Escape', description: 'Close Modal/Panel' },
  { category: 'General', key: '?', description: 'Show Keyboard Shortcuts' },
  { category: 'General', key: 'Cmd+,', description: 'Open Settings' },
];
