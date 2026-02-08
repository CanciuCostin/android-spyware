import { ReactNode, useRef, useState, TouchEvent } from 'react';
import { Trash2, Archive } from 'lucide-react';

interface SwipeableCardProps {
  children: ReactNode;
  onDelete?: () => void;
  onArchive?: () => void;
  deleteThreshold?: number;
  archiveThreshold?: number;
}

export const SwipeableCard = ({
  children,
  onDelete,
  onArchive,
  deleteThreshold = 100,
  archiveThreshold = 100,
}: SwipeableCardProps) => {
  const [offset, setOffset] = useState(0);
  const startX = useRef(0);
  const isDragging = useRef(false);

  const onTouchStart = (e: TouchEvent) => {
    startX.current = e.touches[0].clientX;
    isDragging.current = true;
  };

  const onTouchMove = (e: TouchEvent) => {
    if (!isDragging.current) return;

    const currentX = e.touches[0].clientX;
    const diff = currentX - startX.current;
    
    if ((diff < 0 && onDelete) || (diff > 0 && onArchive)) {
      setOffset(diff);
    }
  };

  const onTouchEnd = () => {
    isDragging.current = false;

    if (offset < -deleteThreshold && onDelete) {
      if (navigator.vibrate) {
        navigator.vibrate(50);
      }
      onDelete();
    } else if (offset > archiveThreshold && onArchive) {
      if (navigator.vibrate) {
        navigator.vibrate(50);
      }
      onArchive();
    }

    setOffset(0);
  };

  return (
    <div className="relative overflow-hidden">
      {onArchive && offset > 0 && (
        <div className="absolute inset-y-0 left-0 flex items-center px-4 bg-blue-500">
          <Archive size={24} className="text-white" />
        </div>
      )}
      {onDelete && offset < 0 && (
        <div className="absolute inset-y-0 right-0 flex items-center px-4 bg-red-500">
          <Trash2 size={24} className="text-white" />
        </div>
      )}
      <div
        className="transition-transform touch-pan-y"
        style={{
          transform: `translateX(${offset}px)`,
          transition: isDragging.current ? 'none' : 'transform 0.3s',
        }}
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
      >
        {children}
      </div>
    </div>
  );
};
