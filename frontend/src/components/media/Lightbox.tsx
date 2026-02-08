import React, { useEffect, useRef, useState, useCallback } from 'react';
import Lightbox from 'yet-another-react-lightbox';
import Zoom from 'yet-another-react-lightbox/plugins/zoom';
import { useMediaStore, MediaItem } from '../../stores/mediaStore';
import './Lightbox.css';

interface LightboxProps {
  items: MediaItem[];
  index: number;
  isOpen: boolean;
  onClose: () => void;
  onPrevious?: () => void;
  onNext?: () => void;
}

interface ExtendedSlide {
  src: string;
  alt?: string;
  title?: string;
  description?: string;
  width?: number;
  height?: number;
  srcSet?: any[];
  item?: MediaItem;
}

export const LightboxComponent: React.FC<LightboxProps> = ({
  items,
  index,
  isOpen,
  onClose,
  onPrevious,
  onNext,
}) => {
  const [currentIndex, setCurrentIndex] = useState(index);
  const [zoom, setZoom] = useState(1);
  const [rotation, setRotation] = useState(0);
  const [showMetadata, setShowMetadata] = useState(true);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setCurrentIndex(index);
  }, [index]);

  const currentItem = items[currentIndex];

  const handlePrevious = () => {
    const newIndex = currentIndex > 0 ? currentIndex - 1 : items.length - 1;
    setCurrentIndex(newIndex);
    setZoom(1);
    setRotation(0);
    if (onPrevious) onPrevious();
  };

  const handleNext = () => {
    const newIndex = currentIndex < items.length - 1 ? currentIndex + 1 : 0;
    setCurrentIndex(newIndex);
    setZoom(1);
    setRotation(0);
    if (onNext) onNext();
  };

  const handleRotate = () => {
    setRotation((prev) => (prev + 90) % 360);
  };

  const handleZoomIn = () => {
    setZoom((prev) => Math.min(prev + 0.25, 5));
  };

  const handleZoomOut = () => {
    setZoom((prev) => Math.max(prev - 0.25, 1));
  };

  const handleResetZoom = () => {
    setZoom(1);
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (!isOpen) return;

    switch (e.key) {
      case 'ArrowLeft':
        handlePrevious();
        break;
      case 'ArrowRight':
        handleNext();
        break;
      case 'Escape':
        onClose();
        break;
      case '+':
      case '=':
        handleZoomIn();
        break;
      case '-':
        handleZoomOut();
        break;
      case 'r':
      case 'R':
        handleRotate();
        break;
      default:
        break;
    }
  };

  useEffect(() => {
    if (isOpen) {
      window.addEventListener('keydown', handleKeyDown);
      return () => window.removeEventListener('keydown', handleKeyDown);
    }
  }, [isOpen, currentIndex]);

  if (!isOpen || items.length === 0) {
    return null;
  }

  const slides: ExtendedSlide[] = items.map((item) => ({
    src: item.url,
    alt: item.filename,
    title: item.filename,
    description: new Date(item.capturedAt).toLocaleString(),
    width: item.width,
    height: item.height,
    item,
  }));

  return (
    <div className="lightbox-wrapper" ref={containerRef}>
      <Lightbox
        slides={slides}
        open={isOpen}
        index={currentIndex}
        close={onClose}
        on={{
          view: ({ index: idx }) => setCurrentIndex(idx),
        }}
        plugins={[Zoom]}
        render={{
          buttonPrev: () => null,
          buttonNext: () => null,
          buttonClose: () => null,
        }}
        carousel={{
          finite: false,
          imageFit: 'contain',
        }}
      />

      {/* Custom controls overlay */}
      <div className="lightbox-controls-container">
        {/* Top controls */}
        <div className="lightbox-top-controls">
          <div className="lightbox-title">
            <span>{currentItem.filename}</span>
          </div>
          <button
            className="lightbox-btn lightbox-close-btn"
            onClick={onClose}
            aria-label="Close lightbox"
            title="Close (Esc)"
          >
            ✕
          </button>
        </div>

        {/* Bottom controls */}
        <div className="lightbox-bottom-controls">
          <div className="lightbox-nav-controls">
            <button
              className="lightbox-btn lightbox-nav-btn"
              onClick={handlePrevious}
              aria-label="Previous image"
              title="Previous (←)"
            >
              ←
            </button>
            <span className="lightbox-counter">
              {currentIndex + 1} / {items.length}
            </span>
            <button
              className="lightbox-btn lightbox-nav-btn"
              onClick={handleNext}
              aria-label="Next image"
              title="Next (→)"
            >
              →
            </button>
          </div>

          <div className="lightbox-zoom-controls">
            <button
              className="lightbox-btn lightbox-zoom-btn"
              onClick={handleZoomOut}
              disabled={zoom <= 1}
              aria-label="Zoom out"
              title="Zoom out (−)"
            >
              −
            </button>
            <span className="lightbox-zoom-level">{Math.round(zoom * 100)}%</span>
            <button
              className="lightbox-btn lightbox-zoom-btn"
              onClick={handleZoomIn}
              disabled={zoom >= 5}
              aria-label="Zoom in"
              title="Zoom in (+)"
            >
              +
            </button>
            <button
              className="lightbox-btn lightbox-action-btn"
              onClick={handleResetZoom}
              disabled={zoom === 1}
              aria-label="Reset zoom"
              title="Reset zoom"
            >
              Reset
            </button>
          </div>

          <div className="lightbox-action-controls">
            <button
              className="lightbox-btn lightbox-action-btn"
              onClick={handleRotate}
              aria-label="Rotate image"
              title="Rotate (R)"
            >
              ↻
            </button>
            <button
              className={`lightbox-btn lightbox-action-btn ${showMetadata ? 'active' : ''}`}
              onClick={() => setShowMetadata(!showMetadata)}
              aria-label="Toggle metadata"
              title="Toggle info (I)"
            >
              ⓘ
            </button>
          </div>
        </div>

        {/* Metadata panel */}
        {showMetadata && (
          <div className="lightbox-metadata-panel">
            <div className="metadata-section">
              <h3>File Information</h3>
              <div className="metadata-item">
                <label>Filename:</label>
                <span>{currentItem.filename}</span>
              </div>
              <div className="metadata-item">
                <label>Size:</label>
                <span>{(currentItem.size / 1024 / 1024).toFixed(2)} MB</span>
              </div>
              {currentItem.width && currentItem.height && (
                <div className="metadata-item">
                  <label>Dimensions:</label>
                  <span>
                    {currentItem.width} × {currentItem.height}
                  </span>
                </div>
              )}
              <div className="metadata-item">
                <label>Captured:</label>
                <span>{new Date(currentItem.capturedAt).toLocaleString()}</span>
              </div>
              {currentItem.appSource && (
                <div className="metadata-item">
                  <label>Source:</label>
                  <span>{currentItem.appSource}</span>
                </div>
              )}
            </div>

            {currentItem.metadata && Object.keys(currentItem.metadata).length > 0 && (
              <div className="metadata-section">
                <h3>Extended Metadata</h3>
                {Object.entries(currentItem.metadata).map(([key, value]) => (
                  <div key={key} className="metadata-item">
                    <label>{key}:</label>
                    <span>{String(value)}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default LightboxComponent;
