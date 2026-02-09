import { useState, useRef, useCallback, useEffect } from 'react';
import { Minimize2, Maximize2, X, Move } from 'lucide-react';

interface PiPPanelProps {
  title: string;
  defaultPosition?: { x: number; y: number };
  defaultSize?: { width: number; height: number };
  minSize?: { width: number; height: number };
  onClose?: () => void;
  children: React.ReactNode;
}

export const PiPPanel: React.FC<PiPPanelProps> = ({
  title,
  defaultPosition = { x: window.innerWidth - 420, y: 20 },
  defaultSize = { width: 400, height: 300 },
  minSize = { width: 200, height: 150 },
  onClose,
  children,
}) => {
  const [position, setPosition] = useState(defaultPosition);
  const [size, setSize] = useState(defaultSize);
  const [isMinimized, setIsMinimized] = useState(false);
  const [isMaximized, setIsMaximized] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [isResizing, setIsResizing] = useState(false);
  const [dragOffset, setDragOffset] = useState({ x: 0, y: 0 });
  const [resizeDirection, setResizeDirection] = useState<string>('');
  
  const panelRef = useRef<HTMLDivElement>(null);
  const savedState = useRef({ position, size });

  const snapThreshold = 20;

  const handleMouseDown = useCallback((e: React.MouseEvent, action: 'drag' | 'resize', direction?: string) => {
    e.preventDefault();
    e.stopPropagation();

    if (action === 'drag') {
      setIsDragging(true);
      setDragOffset({
        x: e.clientX - position.x,
        y: e.clientY - position.y,
      });
    } else if (action === 'resize' && direction) {
      setIsResizing(true);
      setResizeDirection(direction);
    }
  }, [position]);

  const handleMouseMove = useCallback(
    (e: MouseEvent) => {
      if (isDragging) {
        let newX = e.clientX - dragOffset.x;
        let newY = e.clientY - dragOffset.y;

        // Snap to edges
        if (newX < snapThreshold) newX = 0;
        if (newY < snapThreshold) newY = 0;
        if (newX + size.width > window.innerWidth - snapThreshold) {
          newX = window.innerWidth - size.width;
        }
        if (newY + size.height > window.innerHeight - snapThreshold) {
          newY = window.innerHeight - size.height;
        }

        setPosition({ x: newX, y: newY });
      } else if (isResizing) {
        const deltaX = e.movementX;
        const deltaY = e.movementY;

        setSize((prevSize) => {
          let newWidth = prevSize.width;
          let newHeight = prevSize.height;

          if (resizeDirection.includes('e')) {
            newWidth = Math.max(minSize.width, prevSize.width + deltaX);
          }
          if (resizeDirection.includes('s')) {
            newHeight = Math.max(minSize.height, prevSize.height + deltaY);
          }
          if (resizeDirection.includes('w')) {
            const proposed = prevSize.width - deltaX;
            if (proposed >= minSize.width) {
              newWidth = proposed;
              setPosition((prev) => ({ ...prev, x: prev.x + deltaX }));
            }
          }
          if (resizeDirection.includes('n')) {
            const proposed = prevSize.height - deltaY;
            if (proposed >= minSize.height) {
              newHeight = proposed;
              setPosition((prev) => ({ ...prev, y: prev.y + deltaY }));
            }
          }

          return { width: newWidth, height: newHeight };
        });
      }
    },
    [isDragging, isResizing, dragOffset, resizeDirection, size, minSize, snapThreshold]
  );

  const handleMouseUp = useCallback(() => {
    setIsDragging(false);
    setIsResizing(false);
    setResizeDirection('');
  }, []);

  useEffect(() => {
    if (isDragging || isResizing) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
      return () => {
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
      };
    }
  }, [isDragging, isResizing, handleMouseMove, handleMouseUp]);

  const toggleMinimize = () => {
    if (!isMinimized) {
      savedState.current = { position, size };
      setSize({ width: 300, height: 40 });
    } else {
      setSize(savedState.current.size);
    }
    setIsMinimized(!isMinimized);
  };

  const toggleMaximize = () => {
    if (!isMaximized) {
      savedState.current = { position, size };
      setPosition({ x: 0, y: 0 });
      setSize({ width: window.innerWidth, height: window.innerHeight });
    } else {
      setPosition(savedState.current.position);
      setSize(savedState.current.size);
    }
    setIsMaximized(!isMaximized);
  };

  return (
    <div
      ref={panelRef}
      className="fixed bg-gray-900 border-2 border-gray-700 rounded-lg shadow-2xl overflow-hidden"
      style={{
        left: `${position.x}px`,
        top: `${position.y}px`,
        width: `${size.width}px`,
        height: `${size.height}px`,
        zIndex: 9999,
      }}
    >
      {/* Title Bar */}
      <div
        className="flex items-center justify-between bg-gray-800 px-3 py-2 cursor-move select-none"
        onMouseDown={(e) => !isMaximized && handleMouseDown(e, 'drag')}
      >
        <div className="flex items-center gap-2 text-white text-sm font-medium">
          <Move size={14} />
          {title}
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={toggleMinimize}
            className="p-1 hover:bg-gray-700 rounded transition-colors"
            title={isMinimized ? 'Restore' : 'Minimize'}
          >
            <Minimize2 size={14} className="text-white" />
          </button>
          <button
            onClick={toggleMaximize}
            className="p-1 hover:bg-gray-700 rounded transition-colors"
            title={isMaximized ? 'Restore' : 'Maximize'}
          >
            <Maximize2 size={14} className="text-white" />
          </button>
          {onClose && (
            <button
              onClick={onClose}
              className="p-1 hover:bg-red-600 rounded transition-colors"
              title="Close"
            >
              <X size={14} className="text-white" />
            </button>
          )}
        </div>
      </div>

      {/* Content */}
      {!isMinimized && (
        <div className="h-[calc(100%-40px)] overflow-auto">
          {children}
        </div>
      )}

      {/* Resize Handles */}
      {!isMinimized && !isMaximized && (
        <>
          <div
            className="absolute top-0 left-0 w-2 h-2 cursor-nw-resize"
            onMouseDown={(e) => handleMouseDown(e, 'resize', 'nw')}
          />
          <div
            className="absolute top-0 right-0 w-2 h-2 cursor-ne-resize"
            onMouseDown={(e) => handleMouseDown(e, 'resize', 'ne')}
          />
          <div
            className="absolute bottom-0 left-0 w-2 h-2 cursor-sw-resize"
            onMouseDown={(e) => handleMouseDown(e, 'resize', 'sw')}
          />
          <div
            className="absolute bottom-0 right-0 w-2 h-2 cursor-se-resize"
            onMouseDown={(e) => handleMouseDown(e, 'resize', 'se')}
          />
          <div
            className="absolute top-0 left-2 right-2 h-1 cursor-n-resize"
            onMouseDown={(e) => handleMouseDown(e, 'resize', 'n')}
          />
          <div
            className="absolute bottom-0 left-2 right-2 h-1 cursor-s-resize"
            onMouseDown={(e) => handleMouseDown(e, 'resize', 's')}
          />
          <div
            className="absolute left-0 top-2 bottom-2 w-1 cursor-w-resize"
            onMouseDown={(e) => handleMouseDown(e, 'resize', 'w')}
          />
          <div
            className="absolute right-0 top-2 bottom-2 w-1 cursor-e-resize"
            onMouseDown={(e) => handleMouseDown(e, 'resize', 'e')}
          />
        </>
      )}
    </div>
  );
};
