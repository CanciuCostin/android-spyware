import { useEffect, useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { Command } from 'cmdk';
import {
  LayoutDashboard,
  Smartphone,
  Terminal,
  BarChart3,
  Settings,
  Search,
  Clock,
  Folder,
} from 'lucide-react';
import { useLayoutStore } from '../../stores/layoutStore';

interface CommandItem {
  id: string;
  label: string;
  icon: React.ReactNode;
  category: 'Navigation' | 'Devices' | 'Commands';
  action: () => void;
  keywords?: string[];
}

export function CommandPalette() {
  const navigate = useNavigate();
  const { commandPaletteOpen, closeCommandPalette } = useLayoutStore();
  const [search, setSearch] = useState('');
  const [recentCommands, setRecentCommands] = useState<string[]>([]);

  const commands: CommandItem[] = useMemo(
    () => [
      // Navigation
      {
        id: 'nav-dashboard',
        label: 'Go to Dashboard',
        icon: <LayoutDashboard size={18} />,
        category: 'Navigation',
        action: () => {
          navigate('/');
          closeCommandPalette();
          addRecentCommand('nav-dashboard');
        },
      },
      {
        id: 'nav-devices',
        label: 'Go to Devices',
        icon: <Smartphone size={18} />,
        category: 'Navigation',
        action: () => {
          navigate('/devices');
          closeCommandPalette();
          addRecentCommand('nav-devices');
        },
      },
      {
        id: 'nav-commands',
        label: 'Go to Commands',
        icon: <Terminal size={18} />,
        category: 'Navigation',
        action: () => {
          navigate('/commands');
          closeCommandPalette();
          addRecentCommand('nav-commands');
        },
      },
      {
        id: 'nav-analytics',
        label: 'Go to Analytics',
        icon: <BarChart3 size={18} />,
        category: 'Navigation',
        action: () => {
          navigate('/analytics');
          closeCommandPalette();
          addRecentCommand('nav-analytics');
        },
      },
      {
        id: 'nav-settings',
        label: 'Go to Settings',
        icon: <Settings size={18} />,
        category: 'Navigation',
        action: () => {
          navigate('/settings');
          closeCommandPalette();
          addRecentCommand('nav-settings');
        },
      },
      // Devices
      {
        id: 'device-add',
        label: 'Add New Device',
        icon: <Smartphone size={18} />,
        category: 'Devices',
        action: () => {
          console.log('Add device');
          closeCommandPalette();
          addRecentCommand('device-add');
        },
        keywords: ['new', 'create'],
      },
      {
        id: 'device-refresh',
        label: 'Refresh Device List',
        icon: <Smartphone size={18} />,
        category: 'Devices',
        action: () => {
          console.log('Refresh devices');
          closeCommandPalette();
          addRecentCommand('device-refresh');
        },
        keywords: ['reload', 'update'],
      },
      // Commands
      {
        id: 'cmd-execute',
        label: 'Execute Command',
        icon: <Terminal size={18} />,
        category: 'Commands',
        action: () => {
          console.log('Execute command');
          closeCommandPalette();
          addRecentCommand('cmd-execute');
        },
        keywords: ['run', 'shell'],
      },
    ],
    [navigate, closeCommandPalette]
  );

  const addRecentCommand = (id: string) => {
    setRecentCommands((prev) => {
      const filtered = prev.filter((cmd) => cmd !== id);
      return [id, ...filtered].slice(0, 5);
    });
  };

  const recentItems = recentCommands
    .map((id) => commands.find((cmd) => cmd.id === id))
    .filter((cmd): cmd is CommandItem => cmd !== undefined);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        closeCommandPalette();
        setTimeout(() => {
          if (!commandPaletteOpen) {
            useLayoutStore.getState().openCommandPalette();
          }
        }, 100);
      }
    };

    document.addEventListener('keydown', down);
    return () => document.removeEventListener('keydown', down);
  }, [commandPaletteOpen, closeCommandPalette]);

  useEffect(() => {
    if (!commandPaletteOpen) {
      setSearch('');
    }
  }, [commandPaletteOpen]);

  if (!commandPaletteOpen) return null;

  const groupedCommands = commands.reduce((acc, cmd) => {
    if (!acc[cmd.category]) {
      acc[cmd.category] = [];
    }
    acc[cmd.category].push(cmd);
    return acc;
  }, {} as Record<string, CommandItem[]>);

  return (
    <div className="fixed inset-0 z-[100] flex items-start justify-center pt-[20vh] px-4">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={closeCommandPalette}
        aria-hidden="true"
      />

      {/* Command palette */}
      <Command
        className="relative w-full max-w-2xl bg-white rounded-xl shadow-2xl border border-gray-200 overflow-hidden"
        shouldFilter={false}
        label="Command palette"
      >
        <div className="flex items-center px-4 border-b border-gray-200">
          <Search className="text-gray-400" size={20} aria-hidden="true" />
          <Command.Input
            value={search}
            onValueChange={setSearch}
            placeholder="Type a command or search..."
            className="w-full px-4 py-4 bg-transparent outline-none text-gray-900 placeholder-gray-400"
            aria-label="Search commands"
          />
          <kbd className="px-2 py-1 text-xs text-gray-500 bg-gray-100 border border-gray-200 rounded" aria-label="Press Escape to close">
            ESC
          </kbd>
        </div>

        <Command.List className="max-h-[400px] overflow-y-auto p-2">
          <Command.Empty className="py-8 text-center text-sm text-gray-500">
            No results found.
          </Command.Empty>

          {/* Recent commands */}
          {recentItems.length > 0 && !search && (
            <Command.Group
              heading={
                <div className="flex items-center gap-2 px-2 py-1.5 text-xs font-semibold text-gray-500 uppercase">
                  <Clock size={14} aria-hidden="true" />
                  Recent
                </div>
              }
            >
              {recentItems.map((item) => (
                <Command.Item
                  key={item.id}
                  value={item.label}
                  onSelect={item.action}
                  className="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer
                    text-gray-700 hover:bg-gray-100 transition-colors
                    aria-selected:bg-cyan-50 aria-selected:text-cyan-700"
                >
                  <span className="text-gray-500" aria-hidden="true">{item.icon}</span>
                  <span className="flex-1">{item.label}</span>
                </Command.Item>
              ))}
            </Command.Group>
          )}

          {/* Command groups */}
          {Object.entries(groupedCommands).map(([category, items]) => (
            <Command.Group
              key={category}
              heading={
                <div className="flex items-center gap-2 px-2 py-1.5 text-xs font-semibold text-gray-500 uppercase">
                  <Folder size={14} aria-hidden="true" />
                  {category}
                </div>
              }
            >
              {items
                .filter((item) => {
                  if (!search) return true;
                  const searchLower = search.toLowerCase();
                  return (
                    item.label.toLowerCase().includes(searchLower) ||
                    item.keywords?.some((kw) => kw.includes(searchLower))
                  );
                })
                .map((item) => (
                  <Command.Item
                    key={item.id}
                    value={`${item.label} ${item.keywords?.join(' ') || ''}`}
                    onSelect={item.action}
                    className="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer
                      text-gray-700 hover:bg-gray-100 transition-colors
                      aria-selected:bg-cyan-50 aria-selected:text-cyan-700"
                  >
                    <span className="text-gray-500" aria-hidden="true">{item.icon}</span>
                    <span className="flex-1">{item.label}</span>
                  </Command.Item>
                ))}
            </Command.Group>
          ))}
        </Command.List>

        {/* Footer */}
        <div className="flex items-center justify-between px-4 py-2 border-t border-gray-100 bg-gray-50 text-xs text-gray-500" role="status" aria-live="polite">
          <div className="flex items-center gap-4">
            <span className="flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 bg-white border border-gray-200 rounded" aria-label="Use arrow keys to navigate">↑↓</kbd>
              Navigate
            </span>
            <span className="flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 bg-white border border-gray-200 rounded" aria-label="Press Enter to select">↵</kbd>
              Select
            </span>
          </div>
          <span aria-hidden="true">Powered by cmdk</span>
        </div>
      </Command>
    </div>
  );
}
