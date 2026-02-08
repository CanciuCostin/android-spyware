import React, { useEffect, useRef, useState, useCallback } from 'react';
import Masonry from 'react-masonry-css';
import { useMediaStore, MediaItem } from '../../stores/mediaStore';
import './PhotoGallery.css';

const csrfHeaders = () => ({
  'Content-Type': 'application/json',
  'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
});

interface PhotoGalleryProps {
  deviceId: string;
}

export const PhotoGallery: React.FC<PhotoGalleryProps> = ({ deviceId }) => {
  const {
    photos,
    selectedItems,
    filters,
    sort,
    page,
    hasMore,
    loading,
    setPhotos,
    addPhotos,
    toggleSelection,
    selectAll,
    clearSelection,
    setFilters,
    setSort,
    openLightbox,
    setPage,
    setHasMore,
    setLoading,
    deleteItems,
  } = useMediaStore();

  const [selectionMode, setSelectionMode] = useState(false);
  const observerRef = useRef<IntersectionObserver | null>(null);
  const loadMoreRef = useRef<HTMLDivElement>(null);

  // Fetch photos
  const fetchPhotos = useCallback(async (pageNum: number) => {
    setLoading(true);
    try {
      const queryParams = new URLSearchParams({
        page: pageNum.toString(),
        limit: '20',
        sort: sort.field,
        order: sort.order,
        ...(filters.search && { search: filters.search }),
        ...(filters.dateFrom && { dateFrom: filters.dateFrom.toISOString() }),
        ...(filters.dateTo && { dateTo: filters.dateTo.toISOString() }),
        ...(filters.appSource && { appSource: filters.appSource }),
      });

      const response = await fetch(`/api/devices/${deviceId}/photos?${queryParams}`);
      const data = await response.json();

      if (pageNum === 1) {
        setPhotos(data.photos);
      } else {
        addPhotos(data.photos);
      }
      setHasMore(data.hasMore);
    } catch (error) {
      console.error('Failed to fetch photos:', error);
    } finally {
      setLoading(false);
    }
  }, [deviceId, filters, sort, setPhotos, addPhotos, setHasMore, setLoading]);

  // Initial load
  useEffect(() => {
    fetchPhotos(1);
  }, [filters, sort]);

  // Infinite scroll
  useEffect(() => {
    if (observerRef.current) observerRef.current.disconnect();

    observerRef.current = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && hasMore && !loading) {
          const nextPage = page + 1;
          setPage(nextPage);
          fetchPhotos(nextPage);
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
  }, [hasMore, loading, page, fetchPhotos, setPage]);

  // Filtered photos
  const filteredPhotos = photos.filter(photo => {
    if (filters.search && !photo.filename.toLowerCase().includes(filters.search.toLowerCase())) {
      return false;
    }
    return true;
  });

  // Masonry breakpoints
  const breakpointColumns = {
    default: 4,
    1400: 3,
    1000: 2,
    700: 1,
  };

  const handlePhotoClick = (index: number) => {
    if (selectionMode) {
      toggleSelection(filteredPhotos[index].id);
    } else {
      openLightbox(filteredPhotos, index);
    }
  };

  const handleSelectAll = () => {
    if (selectedItems.size === filteredPhotos.length) {
      clearSelection();
    } else {
      selectAll(filteredPhotos);
    }
  };

  const handleDelete = async () => {
    if (selectedItems.size === 0) return;
    
    if (!confirm(`Delete ${selectedItems.size} photo(s)?`)) return;

    try {
      await fetch(`/api/devices/${deviceId}/photos/bulk-delete`, {
        method: 'POST',
        headers: csrfHeaders(),
        body: JSON.stringify({ ids: Array.from(selectedItems) }),
      });
      deleteItems(Array.from(selectedItems));
      setSelectionMode(false);
    } catch (error) {
      console.error('Failed to delete photos:', error);
      alert('Failed to delete photos');
    }
  };

  const handleDownload = async () => {
    if (selectedItems.size === 0) return;

    try {
      const response = await fetch(`/api/devices/${deviceId}/photos/bulk-download`, {
        method: 'POST',
        headers: csrfHeaders(),
        body: JSON.stringify({ ids: Array.from(selectedItems) }),
      });
      
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `photos_${Date.now()}.zip`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error('Failed to download photos:', error);
      alert('Failed to download photos');
    }
  };

  return (
    <div className="photo-gallery">
      {/* Toolbar */}
      <div className="gallery-toolbar">
        <div className="toolbar-left">
          <input
            type="text"
            placeholder="Search photos..."
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
                {selectedItems.size === filteredPhotos.length ? 'Deselect All' : 'Select All'}
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

      {/* Gallery */}
      {filteredPhotos.length === 0 && !loading ? (
        <div className="empty-state">
          <p>No photos found</p>
        </div>
      ) : (
        <Masonry
          breakpointCols={breakpointColumns}
          className="photo-masonry"
          columnClassName="photo-masonry-column"
        >
          {filteredPhotos.map((photo, index) => (
            <div
              key={photo.id}
              className={`photo-item ${selectedItems.has(photo.id) ? 'selected' : ''}`}
              onClick={() => handlePhotoClick(index)}
            >
              <img
                src={photo.thumbnailUrl || photo.url}
                alt={photo.filename}
                loading="lazy"
                className="photo-image"
              />
              {selectionMode && (
                <div className="selection-overlay">
                  <input
                    type="checkbox"
                    checked={selectedItems.has(photo.id)}
                    onChange={() => {}}
                    className="selection-checkbox"
                  />
                </div>
              )}
              <div className="photo-info">
                <span className="photo-filename">{photo.filename}</span>
                <span className="photo-date">
                  {new Date(photo.capturedAt).toLocaleDateString()}
                </span>
              </div>
            </div>
          ))}
        </Masonry>
      )}

      {/* Loading indicator */}
      {loading && (
        <div className="loading-indicator">
          <div className="spinner"></div>
        </div>
      )}

      {/* Infinite scroll trigger */}
      <div ref={loadMoreRef} style={{ height: '1px' }}></div>
    </div>
  );
};
