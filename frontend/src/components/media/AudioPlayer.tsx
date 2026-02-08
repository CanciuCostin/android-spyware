import React, { useRef, useState, useCallback, useEffect } from 'react';
import { MediaItem } from '../../stores/mediaStore';
import './AudioPlayer.css';

interface AudioPlayerProps {
  audio: MediaItem;
  compact?: boolean;
  onPlayingChange?: (isPlaying: boolean) => void;
}

export const AudioPlayer: React.FC<AudioPlayerProps> = ({
  audio,
  compact = false,
  onPlayingChange,
}) => {
  const audioRef = useRef<HTMLAudioElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);
  const [playbackRate, setPlaybackRate] = useState(1);
  const [buffered, setBuffered] = useState(0);
  const animationFrameRef = useRef<number>();

  // Initialize audio context for waveform
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);

  // Handle play/pause
  const handlePlayPause = useCallback(() => {
    if (audioRef.current) {
      if (isPlaying) {
        audioRef.current.pause();
        setIsPlaying(false);
      } else {
        audioRef.current.play();
        setIsPlaying(true);
      }
    }
  }, [isPlaying]);

  // Notify parent of playing state change
  useEffect(() => {
    if (onPlayingChange) {
      onPlayingChange(isPlaying);
    }
  }, [isPlaying, onPlayingChange]);

  // Handle timeupdate
  const handleTimeUpdate = useCallback(() => {
    if (audioRef.current) {
      setCurrentTime(audioRef.current.currentTime);
      if (audioRef.current.buffered.length > 0) {
        setBuffered(audioRef.current.buffered.end(audioRef.current.buffered.length - 1));
      }
    }
  }, []);

  // Handle loadedmetadata
  const handleLoadedMetadata = useCallback(() => {
    if (audioRef.current) {
      setDuration(audioRef.current.duration);
    }
  }, []);

  // Initialize audio context and analyser
  const initializeAudioContext = useCallback(() => {
    if (!audioContextRef.current && audioRef.current) {
      try {
        const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
        audioContextRef.current = audioContext;

        const analyser = audioContext.createAnalyser();
        analyserRef.current = analyser;
        analyser.fftSize = 256;

        const source = audioContext.createMediaElementAudioSource(audioRef.current);
        source.connect(analyser);
        analyser.connect(audioContext.destination);
      } catch (error) {
        console.error('Error initializing audio context:', error);
      }
    }
  }, []);

  // Draw waveform
  const drawWaveform = useCallback(() => {
    if (!canvasRef.current || !analyserRef.current) return;

    const canvas = canvasRef.current;
    const analyser = analyserRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const dataArray = new Uint8Array(analyser.frequencyBinCount);
    analyser.getByteFrequencyData(dataArray);

    // Clear canvas
    ctx.fillStyle = 'rgba(33, 150, 243, 0.05)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Draw bars
    const barWidth = canvas.width / dataArray.length;
    const barHeight = canvas.height;

    ctx.fillStyle = 'rgba(33, 150, 243, 0.7)';
    for (let i = 0; i < dataArray.length; i++) {
      const value = dataArray[i] / 255;
      const height = value * barHeight;

      ctx.fillRect(i * barWidth, barHeight - height, barWidth - 1, height);
    }

    if (isPlaying) {
      animationFrameRef.current = requestAnimationFrame(drawWaveform);
    }
  }, [isPlaying]);

  // Start waveform animation on play
  useEffect(() => {
    if (isPlaying) {
      initializeAudioContext();
      drawWaveform();
    }
    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [isPlaying, drawWaveform, initializeAudioContext]);

  // Handle volume change
  const handleVolumeChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const newVolume = parseFloat(e.target.value);
    setVolume(newVolume);
    if (audioRef.current) {
      audioRef.current.volume = newVolume;
    }
  }, []);

  // Handle playback rate change
  const handlePlaybackRateChange = useCallback((rate: number) => {
    setPlaybackRate(rate);
    if (audioRef.current) {
      audioRef.current.playbackRate = rate;
    }
  }, []);

  // Handle seek
  const handleSeek = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const newTime = parseFloat(e.target.value);
    setCurrentTime(newTime);
    if (audioRef.current) {
      audioRef.current.currentTime = newTime;
    }
  }, []);

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
          if (audioRef.current) {
            audioRef.current.currentTime = Math.min(
              audioRef.current.currentTime + 5,
              duration
            );
          }
          break;
        case 'ArrowLeft':
          e.preventDefault();
          if (audioRef.current) {
            audioRef.current.currentTime = Math.max(audioRef.current.currentTime - 5, 0);
          }
          break;
        case 'm':
        case 'M':
          e.preventDefault();
          setVolume(volume === 0 ? 1 : 0);
          if (audioRef.current) {
            audioRef.current.volume = volume === 0 ? 1 : 0;
          }
          break;
        default:
          break;
      }
    },
    [handlePlayPause, duration, volume]
  );

  const formatTime = (seconds: number): string => {
    if (isNaN(seconds)) return '0:00';
    const minutes = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${minutes}:${String(secs).padStart(2, '0')}`;
  };

  const bufferPercentage = duration > 0 ? (buffered / duration) * 100 : 0;
  const progressPercentage = duration > 0 ? (currentTime / duration) * 100 : 0;

  if (compact) {
    return (
      <div className="audio-player-compact" onKeyDown={handleKeyDown} tabIndex={0}>
        <audio
          ref={audioRef}
          src={audio.url}
          onPlay={() => setIsPlaying(true)}
          onPause={() => setIsPlaying(false)}
          onTimeUpdate={handleTimeUpdate}
          onLoadedMetadata={handleLoadedMetadata}
        />

        <button
          onClick={handlePlayPause}
          className="compact-play-btn"
          aria-label={isPlaying ? 'Pause' : 'Play'}
        >
          {isPlaying ? '⏸' : '▶'}
        </button>

        <div className="compact-progress-container">
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
          />
        </div>

        <span className="compact-time-display">{formatTime(currentTime)}</span>
      </div>
    );
  }

  return (
    <div
      className="audio-player"
      onKeyDown={handleKeyDown}
      tabIndex={0}
      role="region"
      aria-label="Audio player"
    >
      <audio
        ref={audioRef}
        src={audio.url}
        onPlay={() => setIsPlaying(true)}
        onPause={() => setIsPlaying(false)}
        onTimeUpdate={handleTimeUpdate}
        onLoadedMetadata={handleLoadedMetadata}
      />

      {/* Waveform visualization */}
      <div className="waveform-container">
        <canvas
          ref={canvasRef}
          className="waveform-canvas"
          width={400}
          height={100}
        />
        {!isPlaying && (
          <div className="waveform-overlay">
            <button
              className="waveform-play-btn"
              onClick={handlePlayPause}
              aria-label="Play"
            >
              ▶
            </button>
          </div>
        )}
      </div>

      {/* Controls */}
      <div className="audio-controls">
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

          <span className="time-display">
            {formatTime(currentTime)} / {formatTime(duration)}
          </span>
        </div>

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
            aria-label="Audio progress"
          />
        </div>

        {/* Right controls */}
        <div className="controls-right">
          {/* Volume */}
          <div className="volume-control">
            <button
              className="control-btn volume-btn"
              onClick={() => {
                const newVolume = volume === 0 ? 1 : 0;
                setVolume(newVolume);
                if (audioRef.current) {
                  audioRef.current.volume = newVolume;
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

          {/* Playback speed */}
          <select
            value={playbackRate}
            onChange={(e) => handlePlaybackRateChange(parseFloat(e.target.value))}
            className="playback-speed-select"
            aria-label="Playback speed"
            title="Playback speed"
          >
            <option value="0.5">0.5x</option>
            <option value="0.75">0.75x</option>
            <option value="1">1x</option>
            <option value="1.25">1.25x</option>
            <option value="1.5">1.5x</option>
            <option value="2">2x</option>
          </select>
        </div>
      </div>
    </div>
  );
};

export default AudioPlayer;
