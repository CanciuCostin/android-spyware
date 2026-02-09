import React, { useState, useRef, useEffect, useCallback } from 'react';
import { Card, CardHeader, CardTitle, CardContent, Button } from './ui';

export interface ScreenMirrorProps {
  deviceId: string;
  websocketUrl?: string;
}

type SessionStatus = 'inactive' | 'connecting' | 'active' | 'error';

interface SessionInfo {
  session_id: string;
  started_at: string;
  fps: number;
  quality: number;
  max_duration_seconds: number;
  elapsed_seconds?: number;
  remaining_seconds?: number;
}

export const ScreenMirror: React.FC<ScreenMirrorProps> = ({ deviceId, websocketUrl }) => {
  const [status, setStatus] = useState<SessionStatus>('inactive');
  const [consentGranted, setConsentGranted] = useState<boolean | null>(null);
  const [session, setSession] = useState<SessionInfo | null>(null);
  const [fps, setFps] = useState(15);
  const [quality, setQuality] = useState(70);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const wsRef = useRef<WebSocket | null>(null);

  const formatTime = (seconds: number): string => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const checkConsent = useCallback(async () => {
    try {
      const res = await fetch(`/api/devices/${deviceId}/screen/status`);
      const data = await res.json();
      setConsentGranted(data.data?.status !== 'consent_required');
      if (data.data?.status === 'active') {
        setStatus('active');
        setSession(data.data);
      }
    } catch {
      setConsentGranted(null);
    }
  }, [deviceId]);

  useEffect(() => {
    checkConsent();
  }, [checkConsent]);

  useEffect(() => {
    if (status === 'active') {
      timerRef.current = setInterval(() => {
        setElapsedSeconds((prev) => prev + 1);
      }, 1000);
    } else {
      if (timerRef.current) clearInterval(timerRef.current);
      setElapsedSeconds(0);
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [status]);

  const connectWebSocket = useCallback(() => {
    const url = websocketUrl || `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/cable`;
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      const subscribe = JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({ channel: 'ScreenMirrorChannel', device_id: deviceId }),
      });
      ws.send(subscribe);
    };

    ws.onmessage = (event) => {
      try {
        const payload = JSON.parse(event.data);
        if (payload.type === 'ping' || payload.type === 'welcome' || payload.type === 'confirm_subscription') return;

        const message = payload.message;
        if (!message) return;

        switch (message.type) {
          case 'frame':
            renderFrame(message.data);
            break;
          case 'session_started':
            setStatus('active');
            setSession(message.session);
            setError(null);
            break;
          case 'session_stopped':
            setStatus('inactive');
            setSession(null);
            break;
          case 'session_timeout':
            setStatus('inactive');
            setSession(null);
            setError('Session timed out (max 30 minutes)');
            break;
          case 'settings_updated':
            setSession(message.session);
            break;
          case 'error':
            setError(message.message);
            setStatus('error');
            break;
        }
      } catch {
        // ignore parse errors
      }
    };

    ws.onclose = () => {
      if (status === 'active') {
        setTimeout(() => connectWebSocket(), 3000);
      }
    };
  }, [deviceId, websocketUrl, status]);

  const renderFrame = (frameData: string) => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const img = new Image();
    img.onload = () => {
      canvas.width = img.width;
      canvas.height = img.height;
      ctx.drawImage(img, 0, 0);
    };
    img.src = `data:image/jpeg;base64,${frameData}`;
  };

  const handleStart = async () => {
    setStatus('connecting');
    setError(null);

    try {
      const res = await fetch(`/api/devices/${deviceId}/screen/start`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fps, quality }),
      });

      const data = await res.json();
      if (res.ok && data.status === 'ok') {
        setSession(data.data);
        connectWebSocket();
      } else {
        setError(data.message || 'Failed to start session');
        setStatus('error');
      }
    } catch (err) {
      setError('Network error');
      setStatus('error');
    }
  };

  const handleStop = async () => {
    try {
      await fetch(`/api/devices/${deviceId}/screen/stop`, { method: 'POST' });
    } catch {
      // best-effort
    }
    wsRef.current?.close();
    wsRef.current = null;
    setStatus('inactive');
    setSession(null);
  };

  const handleScreenshot = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const link = document.createElement('a');
    link.download = `screen_${deviceId}_${Date.now()}.png`;
    link.href = canvas.toDataURL('image/png');
    link.click();
  };

  const toggleFullscreen = () => {
    const container = containerRef.current;
    if (!container) return;

    if (!isFullscreen) {
      container.requestFullscreen?.();
    } else {
      document.exitFullscreen?.();
    }
    setIsFullscreen(!isFullscreen);
  };

  useEffect(() => {
    const handler = () => setIsFullscreen(!!document.fullscreenElement);
    document.addEventListener('fullscreenchange', handler);
    return () => document.removeEventListener('fullscreenchange', handler);
  }, []);

  useEffect(() => {
    return () => {
      wsRef.current?.close();
    };
  }, []);

  const maxDuration = session?.max_duration_seconds || 1800;
  const remaining = Math.max(maxDuration - elapsedSeconds, 0);

  return (
    <Card variant="dark">
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Screen Mirror</CardTitle>
          <div className="flex items-center gap-2">
            {/* Consent badge */}
            <span
              className={`px-2 py-1 rounded text-xs font-medium ${
                consentGranted === true
                  ? 'bg-green-500/20 text-green-400'
                  : consentGranted === false
                    ? 'bg-red-500/20 text-red-400'
                    : 'bg-yellow-500/20 text-yellow-400'
              }`}
            >
              {consentGranted === true ? '✓ Consent Granted' : consentGranted === false ? '✗ Consent Required' : '… Checking'}
            </span>
            {/* Session status */}
            <span
              className={`px-2 py-1 rounded text-xs font-medium ${
                status === 'active'
                  ? 'bg-electric-500/20 text-electric-400'
                  : status === 'connecting'
                    ? 'bg-yellow-500/20 text-yellow-400'
                    : 'bg-white/10 text-white/40'
              }`}
            >
              {status === 'active' ? `● Live ${formatTime(elapsedSeconds)}` : status.charAt(0).toUpperCase() + status.slice(1)}
            </span>
          </div>
        </div>
      </CardHeader>

      <CardContent>
        {error && (
          <div className="mb-4 p-3 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 text-sm">{error}</div>
        )}

        {/* Canvas display */}
        <div ref={containerRef} className="relative mb-4 rounded-lg bg-dark-950 border border-white/10 overflow-hidden">
          <canvas ref={canvasRef} className="w-full h-auto min-h-[300px] bg-black" />
          {status === 'inactive' && (
            <div className="absolute inset-0 flex items-center justify-center text-white/40">
              <p>Screen mirroring inactive. Press Start to begin.</p>
            </div>
          )}
          {status === 'connecting' && (
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="animate-spin w-8 h-8 border-2 border-electric-400 border-t-transparent rounded-full" />
            </div>
          )}
        </div>

        {/* Session timer */}
        {status === 'active' && (
          <div className="mb-4 flex items-center justify-between text-sm text-white/60">
            <span>Elapsed: {formatTime(elapsedSeconds)}</span>
            <div className="flex-1 mx-4 h-1 bg-white/10 rounded overflow-hidden">
              <div
                className="h-full bg-electric-500 transition-all"
                style={{ width: `${(elapsedSeconds / maxDuration) * 100}%` }}
              />
            </div>
            <span>Remaining: {formatTime(remaining)}</span>
          </div>
        )}

        {/* Controls */}
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <label className="block text-sm text-white/60 mb-1">Quality ({quality}%)</label>
            <input
              type="range"
              min={10}
              max={100}
              step={5}
              value={quality}
              onChange={(e) => setQuality(Number(e.target.value))}
              disabled={status === 'active'}
              className="w-full"
            />
          </div>
          <div>
            <label className="block text-sm text-white/60 mb-1">FPS ({fps})</label>
            <select
              value={fps}
              onChange={(e) => setFps(Number(e.target.value))}
              disabled={status === 'active'}
              className="w-full bg-dark-800 border border-white/10 rounded px-3 py-1.5 text-sm text-white"
            >
              {[1, 5, 10, 15, 20, 25, 30].map((v) => (
                <option key={v} value={v}>
                  {v} FPS
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex gap-2">
          {status === 'inactive' || status === 'error' ? (
            <Button onClick={handleStart} disabled={consentGranted !== true}>
              Start Mirroring
            </Button>
          ) : (
            <Button onClick={handleStop} variant="ghost">
              Stop
            </Button>
          )}
          <Button onClick={handleScreenshot} variant="ghost" disabled={status !== 'active'}>
            📸 Screenshot
          </Button>
          <Button onClick={toggleFullscreen} variant="ghost" disabled={status !== 'active'}>
            {isFullscreen ? '⊡ Exit Fullscreen' : '⊞ Fullscreen'}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
};
