import { useState } from 'react';
import {
  Search,
  User,
  Menu,
  Wifi,
  WifiOff,
  ChevronDown,
} from 'lucide-react';
import { useLayoutStore } from '../../stores/layoutStore';
import { NotificationBell } from '../notifications';

export function TopNav() {
  const { toggleSidebar, openCommandPalette, isMobile } = useLayoutStore();
  const [isConnected] = useState(true);
  const [showUserMenu, setShowUserMenu] = useState(false);

  return (
    <header className="sticky top-0 z-30 bg-white border-b border-gray-200 shadow-sm">
      <div className="flex items-center justify-between h-16 px-4 lg:px-6">
        {/* Left section */}
        <div className="flex items-center gap-4 flex-1">
          {isMobile && (
            <button
              onClick={toggleSidebar}
              className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              aria-label="Toggle sidebar"
            >
              <Menu size={20} />
            </button>
          )}

          {/* Search bar - hidden on mobile */}
          <div className="hidden md:flex items-center flex-1 max-w-md">
            <div className="relative w-full">
              <Search
                className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
                size={18}
              />
              <input
                type="text"
                placeholder="Search or press Cmd+K..."
                onClick={openCommandPalette}
                readOnly
                className="w-full pl-10 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-lg
                  text-sm placeholder-gray-500 cursor-pointer
                  hover:bg-gray-100 transition-colors"
              />
              <kbd className="absolute right-3 top-1/2 -translate-y-1/2
                px-2 py-1 text-xs text-gray-500 bg-white border border-gray-200 rounded">
                ⌘K
              </kbd>
            </div>
          </div>
        </div>

        {/* Right section */}
        <div className="flex items-center gap-2 lg:gap-4">
          {/* Connection status */}
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-gray-50">
            {isConnected ? (
              <>
                <Wifi size={16} className="text-green-500" />
                <span className="hidden sm:inline text-xs font-medium text-gray-700">
                  Connected
                </span>
              </>
            ) : (
              <>
                <WifiOff size={16} className="text-red-500" />
                <span className="hidden sm:inline text-xs font-medium text-gray-700">
                  Disconnected
                </span>
              </>
            )}
          </div>

          {/* Search button - mobile only */}
          <button
            onClick={openCommandPalette}
            className="md:hidden p-2 hover:bg-gray-100 rounded-lg transition-colors"
            aria-label="Search"
          >
            <Search size={20} />
          </button>

          {/* Notifications - Using NotificationBell component */}
          <NotificationBell />

          {/* User menu */}
          <div className="relative">
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              className="flex items-center gap-2 px-3 py-2 hover:bg-gray-100 rounded-lg transition-colors"
              aria-label="User menu"
            >
              <div className="w-8 h-8 bg-gradient-to-br from-cyan-400 to-blue-500 rounded-full
                flex items-center justify-center">
                <User size={18} className="text-white" />
              </div>
              <ChevronDown size={16} className="hidden sm:block text-gray-600" />
            </button>

            {/* Dropdown menu */}
            {showUserMenu && (
              <>
                <div
                  className="fixed inset-0 z-40"
                  onClick={() => setShowUserMenu(false)}
                />
                <div className="absolute right-0 mt-2 w-48 bg-white border border-gray-200
                  rounded-lg shadow-lg z-50">
                  <div className="p-3 border-b border-gray-100">
                    <p className="font-medium text-sm">Admin User</p>
                    <p className="text-xs text-gray-500">admin@example.com</p>
                  </div>
                  <div className="py-1">
                    <button className="w-full px-4 py-2 text-left text-sm hover:bg-gray-50
                      transition-colors">
                      Profile Settings
                    </button>
                    <button className="w-full px-4 py-2 text-left text-sm hover:bg-gray-50
                      transition-colors">
                      Preferences
                    </button>
                    <button className="w-full px-4 py-2 text-left text-sm text-red-600
                      hover:bg-red-50 transition-colors">
                      Sign Out
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
