import React, { useEffect, useRef, useState, useCallback } from 'react';
import { useMediaStore, MediaItem } from '../../stores/mediaStore';
import './VideoGallery.css';

interface VideoGalleryProps {
  deviceId: string;
}

export const VideoGallery: React.FC<VideoGalleryProps> = ({ deviceId }) => {
  const {
    videos,
    selectedItems,
    filters,
    sort,
    page,
    hasMore,
    loading,
    setVideos,
    addVideos,
    toggleSelection,
    selectAll,
    clearSelection,
    setFilters,
    setSort,
    setPage,
    setHasMore,
    setLoading,
    deleteItems,
  } = useMediaStore();

  const [selectionMode, setSelectionMode] = useState(false);
  const [selectedVideo, setSelectedVideo] = useState<MediaItem | null>(null);
  const [showModal, setShowModal] = useState(false);
  const observerRef = useRef<IntersectionObserver | null>(null);
  const loadMoreRef = useRef<HTMLDivElement>(null);

  // Fetch videos
  const fetchVideos = useCallback(
    async (pageNum: number) => {
      setLoading(true);
      try {
        const queryParams = new URLSearchParams({
          page: pageNum.toString(),
          limit: '12',
          sort: sort.field,
          order: sort.order,
          ...(filters.search && { search: filters.search }),
          ...(filters.dateFrom && { dateFrom: filters.dateFrom.toISOString() }),
          ...(filters.dateTo && { dateTo: filters.dateTo.toISOString() }),
          ...(filters.appSource && { appSource: filters.appSource }),
        });

        const response = await fetch(`/api/devices/${deviceId}/videos?${queryParams}`);
        const data = await response.json();

        if (pageNum === 1) {
          setVideos(data.videos);
        } else {
          addVideos(data.videos);
        }
        setHasMore(data.hasMore);
      } catch (error) {
        console.error('Failed to fetch videos:', error);
      } finally {
        setLoading(false);
      }
    },
    [deviceId, filters, sort, setVideos, addVideos, setHasMore, setLoading]
  );

  // Initial load
  useEffect(() => {
    fetchVideos(1);
  }, [filters, sort]);

  // Infinite scroll
  useEffect(() => {
    if (observerRef.current) observerRef.current.disconnect();

    observerRef.current = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && hasMore && !loading) {
          const nextPage = page + 1;
          setPage(nextPage);
          fetchVideos(nextPage);
        }
      },
      { threshold: 0.1 }
    );

    if (loadMoreRef.current) {
      observerRef.current.observe(loadMoreRef.current);
    }

    return () => {
      if (observerRef.current) observerRef.current.disconnect();
    };
  }, [hasMore, loading, page, fetchVideos, setPage]);

  const handleVideoClick = (video: MediaItem) => {
    if (selectionMode) {
      toggleSelection(video.id);
    } else {
      setSelectedVideo(video);
      setShowModal(true);
    }
  };

  const handleSelectAll = () => {
    if (selectedItems.size === videos.length) {
      clearSelection();
    } else {
      selectAll(videos);
    }
  };

  const handleDelete = async () => {
    if (selectedItems.size === 0) return;
    if (!confirm(`Delete ${selectedItems.size} video(s)?`)) return;

    try {
      await fetch(`/api/devices/${deviceId}/videos/bulk-delete`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ids: Array.from(selectedItems) }),
      });
      deleteItems(Array.from(selectedItems));
      setSelectionMode(false);
    } catch (error) {
      console.error('Failed to delete videos:', error);
      alert('Failed to delete videos');
    }
  };

  const handleDownload = async () => {
    if (selectedItems.size === 0) return;

    try {
      const response = await fetch(`/api/devices/${deviceId}/videos/bulk-download`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ids: Array.from(selectedItems) }),
      });

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `videos_${Date.now()}.zip`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error('Failed to download videos:', error);
      alert('Failed to download videos');
    }
  };

  return (
    <div className="video-gallery">
      {/* Toolbar */}
      <div className="gallery-toolbar">
        <div className="toolbar-left">
          <input
            type="text"
            placeholder="Search videos..."
            value={filters.search}
            onChange={(e) => setFilters({ search: e.target.value })}
            className="search-input"
          />
          <select
            value={sort.field}
            onChange={(e) => setSort({ ...sort, field: e.target.value as any })}
            className="sort-select"
          >
            <option value="date">Date</option>
            <option value="size">Size</option>
            <option value="name">Name</option>
          </select>
          <button
            onClick={() => setSort({ ...sort, order: sort.order === 'asc' ? 'desc' : 'asc' })}
            className="sort-order-btn"
          >
            {sort.order === 'asc' ? '↑' : '↓'}
          </button>
        </div>
        <div className="toolbar-right">
          <button
            onClick={() => {
              setSelectionMode(!selectionMode);
              clearSelection();
            }}
            className={`selection-mode-btn ${selectionMode ? 'active' : ''}`}
          >
            {selectionMode ? 'Cancel' : 'Select'}
          </button>
          {selectionMode && (
            <>
              <button onClick={handleSelectAll} className="select-all-btn">
                {selectedItems.size === videos.length ? 'Deselect All' : 'Select All'}
              </button>
              <button
                onClick={handleDownload}
                disabled={selectedItems.size === 0}
                className="download-btn"
              >
                Download ({selectedItems.size})
              </button>
              <button
                onClick={handleDelete}
                disabled={selectedItems.size === 0}
                className="delete-btn"
              >
                Delete ({selectedItems.size})
              </button>
            </>
          )}
        </div>
      </div>

      {/* Video grid */}
      {videos.length === 0 && !loading ? (
        <div className="empty-state">
          <p>No videos found</p>
        </div>
      ) : (
        <div className="video-grid">
          {videos.map((video) => (
            <div
              key={video.id}
              className={`video-card ${selectedItems.has(video.id) ? 'selected' : ''}`}
              onClick={() => handleVideoClick(video)}
            >
              <div className="video-thumbnail-wrapper">
                <img
                  src={video.thumbnailUrl || video.url}
                  alt={video.filename}
                  loading="lazy"
                  className="video-thumbnail"
                />
                <div className="video-overlay">
                  <div className="play-button">▶</div>
                  {video.duration && (
                    <span className="video-duration">
                      {Math.floor(video.duration / 60)}:
                      {String(Math.floor(video.duration % 60)).padStart(2, '0')}
                    </span>
                  )}
                </div>
              </div>
              <div className="video-info">
                <h3 className="video-filename">{video.filename}</h3>
                <p className="video-date">
                  {new Date(video.capturedAt).toLocaleDateString()}
                </p>
                {video.size && (
                  <p className="video-size">{(video.size / 1024 / 1024).toFixed(2)} MB</p>
                )}
              </div>
              {selectionMode && (
                <div className="selection-overlay">
                  <input
                    type="checkbox"
                    checked={selectedItems.has(video.id)}
                    onChange={() => {}}
                    className="selection-checkbox"
                  />
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Loading indicator */}
      {loading && (
        <div className="loading-indicator">
          <div className="spinner"></div>
        </div>
      )}

      {/* Infinite scroll trigger */}
      <div ref={loadMoreRef} style={{ height: '1px' }}></div>

      {/* Modal player */}
      {showModal && selectedVideo && (
        <div className="video-modal" onClick={() => setShowModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <button
              className="modal-close-btn"
              onClick={() => setShowModal(false)}
              aria-label="Close modal"
            >
              ✕
            </button>
            <div className="modal-video-container">
              <video
                controls
                autoPlay
                key={selectedVideo.id}
                style={{ width: '100%', height: 'auto' }}
              >
                <source src={selectedVideo.url} />
                Your browser does not support the video tag.
              </video>
            </div>
            <div className="modal-info">
              <h2>{selectedVideo.filename}</h2>
              <p>{new Date(selectedVideo.capturedAt).toLocaleString()}</p>
              <p>{(selectedVideo.size / 1024 / 1024).toFixed(2)} MB</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default VideoGallery;
