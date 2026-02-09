import { useState, useRef, useCallback, useEffect } from 'react';
import { ArrowLeftRight, Maximize2, X } from 'lucide-react';

interface SplitScreenProps {
  orientation?: 'horizontal' | 'vertical';
  defaultSizes?: [number, number];
  device1Id?: string;
  device2Id?: string;
  syncScroll?: boolean;
  onDevice1Change?: (deviceId: string) => void;
  onDevice2Change?: (deviceId: string) => void;
  onClose?: () => void;
  renderPane: (deviceId: string | undefined, paneIndex: number) => React.ReactNode;
}

export const SplitScreen: React.FC<SplitScreenProps> = ({
  orientation = 'vertical',
  defaultSizes = [50, 50],
  device1Id,
  device2Id,
  syncScroll = false,
  onDevice1Change,
  onDevice2Change,
  onClose,
  renderPane,
}) => {
  const [sizes, setSizes] = useState(defaultSizes);
  const [isDragging, setIsDragging] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const pane1Ref = useRef<HTMLDivElement>(null);
  const pane2Ref = useRef<HTMLDivElement>(null);

  const handleMouseDown = useCallback(() => {
    setIsDragging(true);
  }, []);

  const handleMouseUp = useCallback(() => {
    setIsDragging(false);
  }, []);

  const handleMouseMove = useCallback(
    (e: MouseEvent) => {
      if (!isDragging || !containerRef.current) return;

      const container = containerRef.current;
      const rect = container.getBoundingClientRect();

      let newSize1: number;
      if (orientation === 'vertical') {
        const relativeX = e.clientX - rect.left;
        newSize1 = (relativeX / rect.width) * 100;
      } else {
        const relativeY = e.clientY - rect.top;
        newSize1 = (relativeY / rect.height) * 100;
      }

      // Constrain sizes between 10% and 90%
      newSize1 = Math.max(10, Math.min(90, newSize1));
      const newSize2 = 100 - newSize1;

      setSizes([newSize1, newSize2]);
    },
    [isDragging, orientation]
  );

  useEffect(() => {
    if (isDragging) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
      return () => {
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
      };
    }
  }, [isDragging, handleMouseMove, handleMouseUp]);

  // Sync scroll handler
  useEffect(() => {
    if (!syncScroll || !pane1Ref.current || !pane2Ref.current) return;

    const pane1 = pane1Ref.current;
    const pane2 = pane2Ref.current;

    const handleScroll1 = () => {
      if (pane1 && pane2) {
        pane2.scrollTop = pane1.scrollTop;
        pane2.scrollLeft = pane1.scrollLeft;
      }
    };

    const handleScroll2 = () => {
      if (pane1 && pane2) {
        pane1.scrollTop = pane2.scrollTop;
        pane1.scrollLeft = pane2.scrollLeft;
      }
    };

    pane1.addEventListener('scroll', handleScroll1);
    pane2.addEventListener('scroll', handleScroll2);

    return () => {
      pane1.removeEventListener('scroll', handleScroll1);
      pane2.removeEventListener('scroll', handleScroll2);
    };
  }, [syncScroll]);

  const swapDevices = () => {
    const temp = device1Id;
    onDevice1Change?.(device2Id || '');
    onDevice2Change?.(temp || '');
  };

  const maximizePane = (paneIndex: number) => {
    if (paneIndex === 0) {
      setSizes([90, 10]);
    } else {
      setSizes([10, 90]);
    }
  };

  return (
    <div
      ref={containerRef}
      className={`relative flex ${orientation === 'vertical' ? 'flex-row' : 'flex-col'} h-full w-full bg-gray-900`}
    >
      {/* Pane 1 */}
      <div
        ref={pane1Ref}
        className="relative overflow-auto"
        style={{
          [orientation === 'vertical' ? 'width' : 'height']: `${sizes[0]}%`,
        }}
      >
        <div className="absolute top-2 right-2 z-10 flex gap-2">
          <button
            onClick={() => maximizePane(0)}
            className="p-2 bg-gray-800 hover:bg-gray-700 rounded-lg text-white"
            title="Maximize"
          >
            <Maximize2 size={16} />
          </button>
        </div>
        {renderPane(device1Id, 0)}
      </div>

      {/* Divider */}
      <div
        onMouseDown={handleMouseDown}
        className={`
          ${orientation === 'vertical' ? 'w-1 cursor-col-resize' : 'h-1 cursor-row-resize'}
          bg-gray-700 hover:bg-blue-500 transition-colors relative z-20
          ${isDragging ? 'bg-blue-500' : ''}
        `}
      >
        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
          <div className="p-2 bg-gray-800 rounded-full">
            <ArrowLeftRight size={16} className="text-white" />
          </div>
        </div>
      </div>

      {/* Pane 2 */}
      <div
        ref={pane2Ref}
        className="relative overflow-auto"
        style={{
          [orientation === 'vertical' ? 'width' : 'height']: `${sizes[1]}%`,
        }}
      >
        <div className="absolute top-2 right-2 z-10 flex gap-2">
          <button
            onClick={() => maximizePane(1)}
            className="p-2 bg-gray-800 hover:bg-gray-700 rounded-lg text-white"
            title="Maximize"
          >
            <Maximize2 size={16} />
          </button>
        </div>
        {renderPane(device2Id, 1)}
      </div>

      {/* Control Bar */}
      <div className="absolute top-2 left-1/2 transform -translate-x-1/2 z-30 flex gap-2 bg-gray-800 rounded-lg p-2">
        <button
          onClick={swapDevices}
          className="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-white text-sm"
          title="Swap Devices"
        >
          Swap
        </button>
        {onClose && (
          <button
            onClick={onClose}
            className="px-3 py-1 bg-red-600 hover:bg-red-700 rounded text-white text-sm"
            title="Close Split View"
          >
            <X size={16} />
          </button>
        )}
      </div>
    </div>
  );
};
