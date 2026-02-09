import React, { useState } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '../ui';

interface MediaTabProps {
  deviceId: string;
}

type MediaType = 'photos' | 'screenshots' | 'videos' | 'audio';

interface MediaItem {
  id: string;
  type: MediaType;
  url: string;
  thumbnail?: string;
  timestamp: string;
  size?: number;
  duration?: number;
}

export const MediaTab: React.FC<MediaTabProps> = () => {
  const [activeFilter, setActiveFilter] = useState<MediaType | 'all'>('all');
  const [selectedMedia, setSelectedMedia] = useState<MediaItem | null>(null);

  // Mock data - replace with actual API call
  const [mediaItems] = useState<MediaItem[]>([
    {
      id: '1',
      type: 'photos',
      url: '/placeholder-photo.jpg',
      timestamp: new Date(Date.now() - 3600000).toISOString(),
      size: 2048000,
    },
    {
      id: '2',
      type: 'screenshots',
      url: '/placeholder-screenshot.jpg',
      timestamp: new Date(Date.now() - 7200000).toISOString(),
      size: 1024000,
    },
    {
      id: '3',
      type: 'videos',
      url: '/placeholder-video.mp4',
      thumbnail: '/placeholder-video-thumb.jpg',
      timestamp: new Date(Date.now() - 10800000).toISOString(),
      size: 10240000,
      duration: 120,
    },
    {
      id: '4',
      type: 'audio',
      url: '/placeholder-audio.mp3',
      timestamp: new Date(Date.now() - 14400000).toISOString(),
      size: 3072000,
      duration: 180,
    },
  ]);

  const filteredMedia = activeFilter === 'all'
    ? mediaItems
    : mediaItems.filter((item) => item.type === activeFilter);

  const formatBytes = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const filters: { id: MediaType | 'all'; label: string; icon: string }[] = [
    { id: 'all', label: 'All Media', icon: '📁' },
    { id: 'photos', label: 'Photos', icon: '📸' },
    { id: 'screenshots', label: 'Screenshots', icon: '📱' },
    { id: 'videos', label: 'Videos', icon: '🎥' },
    { id: 'audio', label: 'Audio', icon: '🎵' },
  ];

  return (
    <div className="space-y-6">
      {/* Filters */}
      <Card variant="glass">
        <CardContent className="p-4">
          <div className="flex items-center gap-2 overflow-x-auto">
            {filters.map((filter) => (
              <button
                key={filter.id}
                onClick={() => setActiveFilter(filter.id)}
                className={`
                  px-4 py-2 rounded-lg flex items-center gap-2 whitespace-nowrap transition-all
                  ${
                    activeFilter === filter.id
                      ? 'bg-electric-500 text-dark-900'
                      : 'bg-white/5 text-white/60 hover:bg-white/10 hover:text-white'
                  }
                `}
              >
                <span>{filter.icon}</span>
                <span className="font-medium">{filter.label}</span>
              </button>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Media Grid */}
      <Card variant="glass">
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>{filteredMedia.length} Items</CardTitle>
            <button className="px-3 py-1 bg-electric-500 hover:bg-electric-400 text-dark-900 rounded text-sm font-medium transition-colors">
              📥 Download All
            </button>
          </div>
        </CardHeader>
        <CardContent>
          {filteredMedia.length === 0 ? (
            <div className="text-center py-16 text-white/40">
              <div className="text-6xl mb-4">📭</div>
              <p>No media found</p>
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {filteredMedia.map((item) => (
                <MediaCard
                  key={item.id}
                  item={item}
                  onClick={() => setSelectedMedia(item)}
                  formatBytes={formatBytes}
                  formatDuration={formatDuration}
                />
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Lightbox Viewer */}
      {selectedMedia && (
        <MediaLightbox
          item={selectedMedia}
          onClose={() => setSelectedMedia(null)}
          formatBytes={formatBytes}
          formatDuration={formatDuration}
        />
      )}
    </div>
  );
};

const MediaCard: React.FC<{
  item: MediaItem;
  onClick: () => void;
  formatBytes: (bytes: number) => string;
  formatDuration: (seconds: number) => string;
}> = ({ item, onClick, formatBytes, formatDuration }) => {
  const typeIcons: Record<MediaType, string> = {
    photos: '📸',
    screenshots: '📱',
    videos: '🎥',
    audio: '🎵',
  };

  return (
    <button
      onClick={onClick}
      className="group relative aspect-square bg-dark-800 rounded-lg overflow-hidden hover:ring-2 hover:ring-electric-500 transition-all"
    >
      {/* Placeholder */}
      <div className="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-electric-500/20 to-purple-500/20">
        <span className="text-6xl">{typeIcons[item.type]}</span>
      </div>

      {/* Overlay */}
      <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
        <span className="text-white text-2xl">👁️</span>
      </div>

      {/* Info */}
      <div className="absolute bottom-0 left-0 right-0 p-2 bg-gradient-to-t from-black/80 to-transparent">
        <div className="text-xs text-white/80">
          {new Date(item.timestamp).toLocaleDateString()}
        </div>
        {item.size && (
          <div className="text-xs text-white/60">{formatBytes(item.size)}</div>
        )}
        {item.duration && (
          <div className="text-xs text-white/60">{formatDuration(item.duration)}</div>
        )}
      </div>
    </button>
  );
};

const MediaLightbox: React.FC<{
  item: MediaItem;
  onClose: () => void;
  formatBytes: (bytes: number) => string;
  formatDuration: (seconds: number) => string;
}> = ({ item, onClose, formatBytes, formatDuration }) => {
  const typeIcons: Record<MediaType, string> = {
    photos: '📸',
    screenshots: '📱',
    videos: '🎥',
    audio: '🎵',
  };

  return (
    <div
      className="fixed inset-0 bg-black/90 backdrop-blur-sm z-50 flex items-center justify-center p-8"
      onClick={onClose}
    >
      <button
        onClick={onClose}
        className="absolute top-4 right-4 p-2 bg-white/10 hover:bg-white/20 rounded-lg text-white text-2xl transition-colors"
      >
        ✕
      </button>

      <div
        className="max-w-4xl w-full bg-dark-900 rounded-xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Media Content */}
        <div className="aspect-video bg-dark-800 flex items-center justify-center">
          <div className="text-center">
            <div className="text-8xl mb-4">{typeIcons[item.type]}</div>
            <p className="text-white/60">Media Preview Placeholder</p>
            {(item.type === 'videos' || item.type === 'audio') && (
              <div className="mt-4">
                <div className="text-white/40 text-sm">Player would be rendered here</div>
              </div>
            )}
          </div>
        </div>

        {/* Media Info */}
        <div className="p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-xl font-bold text-white">{item.type.charAt(0).toUpperCase() + item.type.slice(1)}</h3>
            <button className="px-4 py-2 bg-electric-500 hover:bg-electric-400 text-dark-900 rounded-lg font-medium transition-colors">
              📥 Download
            </button>
          </div>

          <div className="grid grid-cols-2 gap-4 text-sm">
            <InfoItem label="Date" value={new Date(item.timestamp).toLocaleString()} />
            {item.size && <InfoItem label="Size" value={formatBytes(item.size)} />}
            {item.duration && <InfoItem label="Duration" value={formatDuration(item.duration)} />}
            <InfoItem label="Type" value={item.type} />
          </div>
        </div>
      </div>
    </div>
  );
};

const InfoItem: React.FC<{ label: string; value: string }> = ({ label, value }) => (
  <div>
    <div className="text-white/60 text-xs">{label}</div>
    <div className="text-white">{value}</div>
  </div>
);
