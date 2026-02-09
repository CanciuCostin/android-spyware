import { ReactNode, useEffect } from 'react';
import { X } from 'lucide-react';
import { useSwipe } from '@hooks/useSwipe';

interface SwipeableDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  children: ReactNode;
  title?: string;
}

export const SwipeableDrawer = ({ isOpen, onClose, children, title }: SwipeableDrawerProps) => {
  const swipeHandlers = useSwipe({
    onSwipeLeft: onClose,
    threshold: 100,
  });

  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }

    return () => {
      document.body.style.overflow = '';
    };
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <>
      <div
        className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40 md:hidden"
        onClick={onClose}
      />
      <div
        className={`fixed top-0 left-0 bottom-0 w-80 max-w-[85vw] bg-surface border-r border-border z-50 md:hidden transform transition-transform duration-300 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
        {...swipeHandlers}
      >
        <div className="flex items-center justify-between p-4 border-b border-border">
          {title && <h2 className="text-lg font-semibold">{title}</h2>}
          <button
            onClick={onClose}
            className="ml-auto p-2 hover:bg-surface-hover active:bg-surface-active rounded-lg transition-colors touch-target"
            aria-label="Close drawer"
          >
            <X size={24} />
          </button>
        </div>
        <div className="overflow-y-auto h-[calc(100vh-4rem)]">{children}</div>
      </div>
    </>
  );
};
