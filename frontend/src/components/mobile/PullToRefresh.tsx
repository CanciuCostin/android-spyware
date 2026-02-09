import { ReactNode, useRef, useState, TouchEvent } from 'react';
import { RefreshCw } from 'lucide-react';

interface PullToRefreshProps {
  onRefresh: () => Promise<void>;
  children: ReactNode;
  threshold?: number;
}

export const PullToRefresh = ({ onRefresh, children, threshold = 80 }: PullToRefreshProps) => {
  const [pullDistance, setPullDistance] = useState(0);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const startY = useRef(0);
  const isDragging = useRef(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const onTouchStart = (e: TouchEvent) => {
    const container = containerRef.current;
    if (!container || container.scrollTop > 0) return;

    startY.current = e.touches[0].clientY;
    isDragging.current = true;
  };

  const onTouchMove = (e: TouchEvent) => {
    if (!isDragging.current) return;

    const container = containerRef.current;
    if (!container || container.scrollTop > 0) {
      isDragging.current = false;
      return;
    }

    const currentY = e.touches[0].clientY;
    const diff = currentY - startY.current;

    if (diff > 0) {
      e.preventDefault();
      setPullDistance(Math.min(diff, threshold * 1.5));
    }
  };

  const onTouchEnd = async () => {
    if (!isDragging.current) return;
    isDragging.current = false;

    if (pullDistance >= threshold) {
      setIsRefreshing(true);
      if (navigator.vibrate) {
        navigator.vibrate(30);
      }
      try {
        await onRefresh();
      } finally {
        setIsRefreshing(false);
        setPullDistance(0);
      }
    } else {
      setPullDistance(0);
    }
  };

  const rotation = (pullDistance / threshold) * 360;
  const opacity = Math.min(pullDistance / threshold, 1);

  return (
    <div
      ref={containerRef}
      className="relative overflow-auto h-full"
      onTouchStart={onTouchStart}
      onTouchMove={onTouchMove}
      onTouchEnd={onTouchEnd}
    >
      <div
        className="absolute top-0 left-0 right-0 flex items-center justify-center transition-all"
        style={{
          height: pullDistance,
          opacity,
        }}
      >
        <RefreshCw
          size={24}
          className={`text-primary ${isRefreshing ? 'animate-spin' : ''}`}
          style={{
            transform: isRefreshing ? undefined : `rotate(${rotation}deg)`,
          }}
        />
      </div>
      <div
        style={{
          transform: `translateY(${pullDistance}px)`,
          transition: isDragging.current ? 'none' : 'transform 0.3s',
        }}
      >
        {children}
      </div>
    </div>
  );
};
