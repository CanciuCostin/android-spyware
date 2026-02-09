import { Home, List, Settings, BarChart } from 'lucide-react';
import { Link, useLocation } from 'react-router-dom';

const navItems = [
  { path: '/', icon: Home, label: 'Home' },
  { path: '/devices', icon: List, label: 'Devices' },
  { path: '/analytics', icon: BarChart, label: 'Analytics' },
  { path: '/settings', icon: Settings, label: 'Settings' },
];

export const BottomNavigation = () => {
  const location = useLocation();

  const handleClick = () => {
    if (navigator.vibrate) {
      navigator.vibrate(10);
    }
  };

  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-surface border-t border-border safe-area-inset-bottom z-50">
      <div className="flex justify-around items-center h-16">
        {navItems.map((item) => {
          const isActive = location.pathname === item.path;
          const Icon = item.icon;

          return (
            <Link
              key={item.path}
              to={item.path}
              onClick={handleClick}
              className={`flex flex-col items-center justify-center flex-1 h-full transition-colors ${
                isActive
                  ? 'text-primary'
                  : 'text-muted hover:text-foreground active:text-primary'
              }`}
            >
              <Icon size={24} />
              <span className="text-xs mt-1">{item.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
};
