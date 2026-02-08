import React, { useEffect, useRef, useState, useCallback } from 'react';
import { useMediaStore, MediaItem } from '../../stores/mediaStore';
import { AudioPlayer } from './AudioPlayer';
import './AudioGallery.css';

interface AudioGalleryProps {
  deviceId: string;
}

export const AudioGallery: React.FC<AudioGalleryProps> = ({ deviceId }) => {
  const {
    audios,
    selectedItems,
    filters,
    sort,
    page,
    hasMore,
    loading,
    setAudios,
    addAudios,
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
  const [playingId, setPlayingId] = useState<string | null>(null);
  const observerRef = useRef<IntersectionObserver | null>(null);
  const loadMoreRef = useRef<HTMLDivElement>(null);

  // Fetch audios
  const fetchAudios = useCallback(
    async (pageNum: number) => {
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

        const response = await fetch(`/api/devices/${deviceId}/audios?${queryParams}`);
        const data = await response.json();

        if (pageNum === 1) {
          setAudios(data.audios);
        } else {
          addAudios(data.audios);
        }
        setHasMore(data.hasMore);
      } catch (error) {
        console.error('Failed to fetch audios:', error);
      } finally {
        setLoading(false);
      }
    },
    [deviceId, filters, sort, setAudios, addAudios, setHasMore, setLoading]
  );

  // Initial load
  useEffect(() => {
    fetchAudios(1);
  }, [filters, sort]);

  // Infinite scroll
  useEffect(() => {
    if (observerRef.current) observerRef.current.disconnect();

    observerRef.current = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && hasMore && !loading) {
          const nextPage = page + 1;
          setPage(nextPage);
          fetchAudios(nextPage);
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
  }, [hasMore, loading, page, fetchAudios, setPage]);

  const handleAudioClick = (audio: MediaItem) => {
    if (selectionMode) {
      toggleSelection(audio.id);
    }
  };

  const handleSelectAll = () => {
    if (selectedItems.size === audios.length) {
      clearSelection();
    } else {
      selectAll(audios);
    }
  };

  const handleDelete = async () => {
    if (selectedItems.size === 0) return;
    if (!confirm(`Delete ${selectedItems.size} audio(s)?`)) return;

    try {
      await fetch(`/api/devices/${deviceId}/audios/bulk-delete`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ids: Array.from(selectedItems) }),
      });
      deleteItems(Array.from(selectedItems));
      setSelectionMode(false);
    } catch (error) {
      console.error('Failed to delete audios:', error);
      alert('Failed to delete audios');
    }
  };

  const handleDownload = async () => {
    if (selectedItems.size === 0) return;

    try {
      const response = await fetch(`/api/devices/${deviceId}/audios/bulk-download`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ids: Array.from(selectedItems) }),
      });

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `audios_${Date.now()}.zip`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error('Failed to download audios:', error);
      alert('Failed to download audios');
    }
  };

  return (
    <div className="audio-gallery">
      {/* Toolbar */}
      <div className="gallery-toolbar">
        <div className="toolbar-left">
          <input
            type="text"
            placeholder="Search audio files..."
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
                {selectedItems.size === audios.length ? 'Deselect All' : 'Select All'}
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

      {/* Audio list */}
      {audios.length === 0 && !loading ? (
        <div className="empty-state">
          <p>No audio files found</p>
        </div>
      ) : (
        <div className="audio-list">
          {audios.map((audio) => (
            <div
              key={audio.id}
              className={`audio-item ${selectedItems.has(audio.id) ? 'selected' : ''}`}
              onClick={() => handleAudioClick(audio)}
            >
              {selectionMode && (
                <div className="selection-checkbox-wrapper">
                  <input
                    type="checkbox"
                    checked={selectedItems.has(audio.id)}
                    onChange={() => {}}
                    className="selection-checkbox"
                  />
                </div>
              )}
              <div className="audio-icon">
                <span>♪</span>
              </div>
              <div className="audio-details">
                <h4 className="audio-filename">{audio.filename}</h4>
                <p className="audio-meta">
                  {new Date(audio.capturedAt).toLocaleString()} •{' '}
                  {(audio.size / 1024 / 1024).toFixed(2)} MB
                  {audio.duration && ` • ${Math.floor(audio.duration)}s`}
                </p>
              </div>
              <div className="audio-player-inline">
                <AudioPlayer
                  key={`${audio.id}-${playingId === audio.id}`}
                  audio={audio}
                  isPlaying={playingId === audio.id}
                  onPlayingChange={(isPlaying) => {
                    setPlayingId(isPlaying ? audio.id : null);
                  }}
                  compact={true}
                />
              </div>
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
    </div>
  );
};

export default AudioGallery;
