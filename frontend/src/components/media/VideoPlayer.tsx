import React, { useRef, useState, useCallback, useEffect } from 'react';
import { MediaItem } from '../../stores/mediaStore';
import './VideoPlayer.css';

interface VideoPlayerProps {
  video: MediaItem;
  autoPlay?: boolean;
  onEnded?: () => void;
  fullscreen?: boolean;
}

export const VideoPlayer: React.FC<VideoPlayerProps> = ({
  video,
  autoPlay = false,
  onEnded,
  fullscreen = false,
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [isPlaying, setIsPlaying] = useState(autoPlay);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);
  const [playbackRate, setPlaybackRate] = useState(1);
  const [isFullscreen, setIsFullscreen] = useState(fullscreen);
  const [buffered, setBuffered] = useState(0);
  const [showControls, setShowControls] = useState(true);
  const controlsTimeoutRef = useRef<NodeJS.Timeout>();

  // Handle play/pause
  const handlePlayPause = useCallback(() => {
    if (videoRef.current) {
      if (isPlaying) {
        videoRef.current.pause();
        setIsPlaying(false);
      } else {
        videoRef.current.play();
        setIsPlaying(true);
      }
    }
  }, [isPlaying]);

  // Handle timeupdate
  const handleTimeUpdate = useCallback(() => {
    if (videoRef.current) {
      setCurrentTime(videoRef.current.currentTime);
      if (videoRef.current.buffered.length > 0) {
        setBuffered(videoRef.current.buffered.end(videoRef.current.buffered.length - 1));
      }
    }
  }, []);

  // Handle loadedmetadata
  const handleLoadedMetadata = useCallback(() => {
    if (videoRef.current) {
      setDuration(videoRef.current.duration);
    }
  }, []);

  // Handle volume change
  const handleVolumeChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const newVolume = parseFloat(e.target.value);
    setVolume(newVolume);
    if (videoRef.current) {
      videoRef.current.volume = newVolume;
    }
  }, []);

  // Handle playback rate change
  const handlePlaybackRateChange = useCallback((rate: number) => {
    setPlaybackRate(rate);
    if (videoRef.current) {
      videoRef.current.playbackRate = rate;
    }
  }, []);

  // Handle seek
  const handleSeek = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const newTime = parseFloat(e.target.value);
    setCurrentTime(newTime);
    if (videoRef.current) {
      videoRef.current.currentTime = newTime;
    }
  }, []);

  // Handle fullscreen
  const handleFullscreen = useCallback(async () => {
    if (containerRef.current) {
      if (!isFullscreen) {
        try {
          if (containerRef.current.requestFullscreen) {
            await containerRef.current.requestFullscreen();
            setIsFullscreen(true);
          }
        } catch (error) {
          console.error('Error requesting fullscreen:', error);
        }
      } else {
        if (document.fullscreenElement) {
          await document.exitFullscreen();
          setIsFullscreen(false);
        }
      }
    }
  }, [isFullscreen]);

  // Handle fullscreen change
  const handleFullscreenChange = useCallback(() => {
    setIsFullscreen(!!document.fullscreenElement);
  }, []);

  // Handle mouse move to show/hide controls
  const handleMouseMove = useCallback(() => {
    setShowControls(true);
    if (controlsTimeoutRef.current) {
      clearTimeout(controlsTimeoutRef.current);
    }
    if (isPlaying) {
      controlsTimeoutRef.current = setTimeout(() => {
        setShowControls(false);
      }, 3000);
    }
  }, [isPlaying]);

  // Cleanup timeout on unmount
  useEffect(() => {
    return () => {
      if (controlsTimeoutRef.current) {
        clearTimeout(controlsTimeoutRef.current);
      }
    };
  }, []);

  // Add fullscreen change listener
  useEffect(() => {
    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => {
      document.removeEventListener('fullscreenchange', handleFullscreenChange);
    };
  }, [handleFullscreenChange]);

  // Handle keyboard shortcuts
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLDivElement>) => {
      switch (e.key) {
        case ' ':
          e.preventDefault();
          handlePlayPause();
          break;
        case 'ArrowRight':
          e.preventDefault();
          if (videoRef.current) {
            videoRef.current.currentTime = Math.min(
              videoRef.current.currentTime + 5,
              duration
            );
          }
          break;
        case 'ArrowLeft':
          e.preventDefault();
          if (videoRef.current) {
            videoRef.current.currentTime = Math.max(videoRef.current.currentTime - 5, 0);
          }
          break;
        case 'f':
        case 'F':
          e.preventDefault();
          handleFullscreen();
          break;
        case 'm':
        case 'M':
          e.preventDefault();
          setVolume(volume === 0 ? 1 : 0);
          if (videoRef.current) {
            videoRef.current.volume = volume === 0 ? 1 : 0;
          }
          break;
        case '<':
          e.preventDefault();
          handlePlaybackRateChange(Math.max(playbackRate - 0.25, 0.25));
          break;
        case '>':
          e.preventDefault();
          handlePlaybackRateChange(Math.min(playbackRate + 0.25, 2));
          break;
        default:
          break;
      }
    },
    [handlePlayPause, handleFullscreen, duration, volume, playbackRate, handlePlaybackRateChange]
  );

  const formatTime = (seconds: number): string => {
    if (isNaN(seconds)) return '0:00';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);

    if (hours > 0) {
      return `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }
    return `${minutes}:${String(secs).padStart(2, '0')}`;
  };

  const bufferPercentage = duration > 0 ? (buffered / duration) * 100 : 0;
  const progressPercentage = duration > 0 ? (currentTime / duration) * 100 : 0;

  return (
    <div
      ref={containerRef}
      className={`video-player ${isFullscreen ? 'fullscreen' : ''}`}
      onMouseMove={handleMouseMove}
      onKeyDown={handleKeyDown}
      tabIndex={0}
      role="region"
      aria-label="Video player"
    >
      <video
        ref={videoRef}
        className="video-player-video"
        src={video.url}
        onPlay={() => setIsPlaying(true)}
        onPause={() => setIsPlaying(false)}
        onTimeUpdate={handleTimeUpdate}
        onLoadedMetadata={handleLoadedMetadata}
        onEnded={onEnded}
        onMouseMove={handleMouseMove}
      />

      <div className={`video-player-controls ${showControls ? 'visible' : ''}`}>
        {/* Progress bar */}
        <div className="progress-container">
          <div className="progress-background">
            <div className="progress-buffered" style={{ width: `${bufferPercentage}%` }} />
            <div className="progress-played" style={{ width: `${progressPercentage}%` }} />
          </div>
          <input
            type="range"
            min="0"
            max={duration || 0}
            value={currentTime}
            onChange={handleSeek}
            className="progress-slider"
            aria-label="Video progress"
          />
        </div>

        {/* Controls */}
        <div className="controls-row">
          {/* Left controls */}
          <div className="controls-left">
            <button
              onClick={handlePlayPause}
              className="control-btn play-btn"
              aria-label={isPlaying ? 'Pause' : 'Play'}
              title={isPlaying ? 'Pause (Space)' : 'Play (Space)'}
            >
              {isPlaying ? '⏸' : '▶'}
            </button>

            <div className="volume-control">
              <button
                className="control-btn volume-btn"
                onClick={() => {
                  const newVolume = volume === 0 ? 1 : 0;
                  setVolume(newVolume);
                  if (videoRef.current) {
                    videoRef.current.volume = newVolume;
                  }
                }}
                aria-label="Mute"
                title="Mute (M)"
              >
                {volume === 0 ? '🔇' : volume < 0.5 ? '🔉' : '🔊'}
              </button>
              <input
                type="range"
                min="0"
                max="1"
                step="0.1"
                value={volume}
                onChange={handleVolumeChange}
                className="volume-slider"
                aria-label="Volume"
              />
            </div>

            <span className="time-display">
              {formatTime(currentTime)} / {formatTime(duration)}
            </span>
          </div>

          {/* Right controls */}
          <div className="controls-right">
            {/* Playback speed */}
            <div className="playback-speed-control">
              <select
                value={playbackRate}
                onChange={(e) => handlePlaybackRateChange(parseFloat(e.target.value))}
                className="playback-speed-select"
                aria-label="Playback speed"
                title="Playback speed"
              >
                <option value="0.25">0.25x</option>
                <option value="0.5">0.5x</option>
                <option value="0.75">0.75x</option>
                <option value="1">1x</option>
                <option value="1.25">1.25x</option>
                <option value="1.5">1.5x</option>
                <option value="1.75">1.75x</option>
                <option value="2">2x</option>
              </select>
            </div>

            {/* Fullscreen */}
            <button
              onClick={handleFullscreen}
              className="control-btn fullscreen-btn"
              aria-label={isFullscreen ? 'Exit fullscreen' : 'Enter fullscreen'}
              title={isFullscreen ? 'Exit fullscreen (F)' : 'Fullscreen (F)'}
            >
              {isFullscreen ? '⛶' : '⛶'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default VideoPlayer;
