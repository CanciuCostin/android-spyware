import { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Smartphone,
  Terminal,
  BarChart3,
  Settings,
  ChevronLeft,
  ChevronRight,
  X,
} from 'lucide-react';
import { useLayoutStore } from '../../stores/layoutStore';

interface NavItem {
  name: string;
  path: string;
  icon: React.ReactNode;
}

const navItems: NavItem[] = [
  { name: 'Dashboard', path: '/', icon: <LayoutDashboard size={20} /> },
  { name: 'Devices', path: '/devices', icon: <Smartphone size={20} /> },
  { name: 'Commands', path: '/commands', icon: <Terminal size={20} /> },
  { name: 'Analytics', path: '/analytics', icon: <BarChart3 size={20} /> },
  { name: 'Settings', path: '/settings', icon: <Settings size={20} /> },
];

export function Sidebar() {
  const location = useLocation();
  const { sidebarCollapsed, toggleSidebar, isMobile, closeMobileSidebar } = useLayoutStore();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return null;

  const handleLinkClick = () => {
    if (isMobile) {
      closeMobileSidebar();
    }
  };

  return (
    <>
      {/* Mobile overlay */}
      {isMobile && !sidebarCollapsed && (
        <div
          className="fixed inset-0 bg-black/50 z-40 lg:hidden"
          onClick={closeMobileSidebar}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`
          fixed lg:sticky top-0 left-0 h-screen bg-gray-900 text-white z-50
          transition-all duration-300 ease-in-out
          ${sidebarCollapsed ? (isMobile ? '-translate-x-full' : 'w-16') : 'w-64'}
          ${isMobile && !sidebarCollapsed ? 'translate-x-0' : ''}
          lg:translate-x-0
        `}
      >
        <div className="flex flex-col h-full">
          {/* Header */}
          <div className="flex items-center justify-between h-16 px-4 border-b border-gray-800">
            {!sidebarCollapsed && (
              <>
                <h1 className="text-xl font-bold bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-transparent">
                  EagleSpy
                </h1>
                {isMobile && (
                  <button
                    onClick={closeMobileSidebar}
                    className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
                    aria-label="Close sidebar"
                  >
                    <X size={20} />
                  </button>
                )}
              </>
            )}
            {!isMobile && (
              <button
                onClick={toggleSidebar}
                className={`p-2 hover:bg-gray-800 rounded-lg transition-colors ${sidebarCollapsed ? 'mx-auto' : 'ml-auto'}`}
                aria-label={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
              >
                {sidebarCollapsed ? <ChevronRight size={20} /> : <ChevronLeft size={20} />}
              </button>
            )}
          </div>

          {/* Navigation */}
          <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
            {navItems.map((item) => {
              const isActive = location.pathname === item.path;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  onClick={handleLinkClick}
                  className={`
                    flex items-center gap-3 px-3 py-2.5 rounded-lg
                    transition-all duration-200
                    ${isActive
                      ? 'bg-gradient-to-r from-cyan-500/20 to-blue-500/20 text-cyan-400 border border-cyan-500/30'
                      : 'text-gray-400 hover:text-white hover:bg-gray-800'
                    }
                    ${sidebarCollapsed ? 'justify-center' : ''}
                  `}
                  title={sidebarCollapsed ? item.name : undefined}
                >
                  <span className={isActive ? 'text-cyan-400' : ''}>{item.icon}</span>
                  {!sidebarCollapsed && (
                    <span className="font-medium">{item.name}</span>
                  )}
                </Link>
              );
            })}
          </nav>

          {/* Footer */}
          <div className="p-4 border-t border-gray-800">
            {!sidebarCollapsed && (
              <div className="text-xs text-gray-500 text-center">
                Version 5.0.0
              </div>
            )}
          </div>
        </div>
      </aside>
    </>
  );
}
