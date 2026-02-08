import { Menu, ArrowLeft } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

interface MobileHeaderProps {
  title: string;
  showBack?: boolean;
  onMenuClick?: () => void;
}

export const MobileHeader = ({ title, showBack, onMenuClick }: MobileHeaderProps) => {
  const navigate = useNavigate();

  const handleBack = () => {
    if (navigator.vibrate) {
      navigator.vibrate(10);
    }
    navigate(-1);
  };

  const handleMenu = () => {
    if (navigator.vibrate) {
      navigator.vibrate(10);
    }
    onMenuClick?.();
  };

  return (
    <header className="md:hidden fixed top-0 left-0 right-0 bg-surface border-b border-border safe-area-inset-top z-50">
      <div className="flex items-center h-14 px-4">
        {showBack ? (
          <button
            onClick={handleBack}
            className="p-2 -ml-2 hover:bg-surface-hover active:bg-surface-active rounded-lg transition-colors touch-target"
            aria-label="Go back"
          >
            <ArrowLeft size={24} />
          </button>
        ) : (
          <button
            onClick={handleMenu}
            className="p-2 -ml-2 hover:bg-surface-hover active:bg-surface-active rounded-lg transition-colors touch-target"
            aria-label="Open menu"
          >
            <Menu size={24} />
          </button>
        )}
        <h1 className="flex-1 text-lg font-semibold text-center px-4 truncate">{title}</h1>
        <div className="w-10" />
      </div>
    </header>
  );
};
