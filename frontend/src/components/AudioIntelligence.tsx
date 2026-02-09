import React, { useEffect, useState, useCallback, useRef } from 'react';

interface Speaker {
  id: string;
  label: string;
  segments: Array<{ start: number; end: number }>;
  duration_seconds: number;
}

interface KeywordMatch {
  keyword: string;
  count: number;
  positions: number[];
}

interface Transcription {
  id: number;
  recording_id: number;
  text: string;
  language: string;
  confidence: number | null;
  speakers: Speaker[];
  keywords: KeywordMatch[];
  created_at: string;
}

interface AnalysisResult {
  recording_id: number;
  duration: { estimated_seconds: number; file_size_bytes: number } | null;
  quality: { format: string; file_size_bytes: number; quality_tier: string } | null;
  transcription: { text: string; language: string; confidence: number | null; error?: string } | null;
  language: string;
  speakers: Speaker[];
  keywords: KeywordMatch[];
}

interface AudioIntelligenceProps {
  deviceId: string;
  recordingId?: number;
  apiBasePath?: string;
}

const LANGUAGE_LABELS: Record<string, string> = {
  en: 'English', es: 'Spanish', fr: 'French', de: 'German',
  it: 'Italian', pt: 'Portuguese', zh: 'Chinese', ja: 'Japanese',
  ko: 'Korean', ar: 'Arabic', ru: 'Russian', hi: 'Hindi',
};

const SPEAKER_COLORS = ['#4F46E5', '#059669', '#D97706', '#DC2626', '#7C3AED', '#0891B2'];

const AudioIntelligence: React.FC<AudioIntelligenceProps> = ({
  deviceId,
  recordingId,
  apiBasePath = '/api',
}) => {
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(null);
  const [transcriptions, setTranscriptions] = useState<Transcription[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'transcript' | 'speakers' | 'keywords'>('transcript');
  const audioRef = useRef<HTMLAudioElement>(null);

  const fetchTranscriptions = useCallback(async () => {
    try {
      const res = await fetch(`${apiBasePath}/devices/${deviceId}/audio/transcriptions`);
      const data = await res.json();
      if (data.status === 'success') {
        setTranscriptions(data.data || []);
      }
    } catch (err) {
      console.error('Failed to fetch transcriptions:', err);
    }
  }, [deviceId, apiBasePath]);

  const runAnalysis = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const body: Record<string, unknown> = {};
      if (recordingId) body.recording_id = recordingId;

      const res = await fetch(`${apiBasePath}/devices/${deviceId}/audio/analyze`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (data.status === 'success') {
        setAnalysis(data.data);
      } else {
        setError(data.error || 'Analysis failed');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Analysis failed');
    } finally {
      setLoading(false);
    }
  }, [deviceId, recordingId, apiBasePath]);

  useEffect(() => {
    fetchTranscriptions();
  }, [fetchTranscriptions]);

  const highlightKeywords = (text: string, keywords: KeywordMatch[]): React.ReactNode => {
    if (!keywords || keywords.length === 0) return text;

    const allKeywords = keywords.map(k => k.keyword);
    const pattern = new RegExp(`\\b(${allKeywords.map(k => k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|')})\\b`, 'gi');

    const parts = text.split(pattern);
    return parts.map((part, i) => {
      const isKeyword = allKeywords.some(k => k.toLowerCase() === part.toLowerCase());
      return isKeyword ? (
        <mark key={i} style={{ backgroundColor: '#FEF08A', padding: '0 2px', borderRadius: '2px', fontWeight: 600 }}>
          {part}
        </mark>
      ) : (
        <span key={i}>{part}</span>
      );
    });
  };

  const formatDuration = (seconds: number): string => {
    const m = Math.floor(seconds / 60);
    const s = Math.round(seconds % 60);
    return `${m}:${s.toString().padStart(2, '0')}`;
  };

  return (
    <div style={{ fontFamily: 'system-ui, -apple-system, sans-serif', maxWidth: 900, margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h2 style={{ margin: 0, fontSize: 24, fontWeight: 700 }}>🎤 Audio Intelligence</h2>
        <button
          onClick={runAnalysis}
          disabled={loading}
          style={{
            padding: '10px 20px', backgroundColor: loading ? '#9CA3AF' : '#4F46E5',
            color: '#fff', border: 'none', borderRadius: 8, cursor: loading ? 'default' : 'pointer',
            fontSize: 14, fontWeight: 600,
          }}
        >
          {loading ? 'Analyzing...' : 'Analyze Audio'}
        </button>
      </div>

      {error && (
        <div style={{ padding: 12, backgroundColor: '#FEE2E2', color: '#991B1B', borderRadius: 8, marginBottom: 16 }}>
          {error}
        </div>
      )}

      {/* Audio Player */}
      {analysis && (
        <div style={{ backgroundColor: '#F9FAFB', borderRadius: 12, padding: 20, marginBottom: 24 }}>
          <div style={{ display: 'flex', gap: 24, alignItems: 'center', flexWrap: 'wrap' }}>
            <audio ref={audioRef} controls style={{ flex: 1, minWidth: 250 }}>
              <source src={`/files/dumps/audio/${analysis.recording_id}`} />
            </audio>
            <div style={{ display: 'flex', gap: 16 }}>
              {analysis.duration && (
                <div style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: 12, color: '#6B7280' }}>Duration</div>
                  <div style={{ fontWeight: 600 }}>{formatDuration(analysis.duration.estimated_seconds)}</div>
                </div>
              )}
              {analysis.quality && (
                <div style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: 12, color: '#6B7280' }}>Quality</div>
                  <div style={{ fontWeight: 600, textTransform: 'capitalize' }}>{analysis.quality.quality_tier}</div>
                </div>
              )}
              {/* Language Indicator */}
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 12, color: '#6B7280' }}>Language</div>
                <div style={{
                  fontWeight: 600, backgroundColor: '#EEF2FF', color: '#4338CA',
                  padding: '2px 8px', borderRadius: 12, fontSize: 13,
                }}>
                  {LANGUAGE_LABELS[analysis.language] || analysis.language}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Tabs */}
      {analysis && (
        <>
          <div style={{ display: 'flex', gap: 0, borderBottom: '2px solid #E5E7EB', marginBottom: 20 }}>
            {(['transcript', 'speakers', 'keywords'] as const).map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                style={{
                  padding: '10px 20px', border: 'none', borderBottom: activeTab === tab ? '2px solid #4F46E5' : '2px solid transparent',
                  backgroundColor: 'transparent', cursor: 'pointer', fontWeight: activeTab === tab ? 600 : 400,
                  color: activeTab === tab ? '#4F46E5' : '#6B7280', fontSize: 14, textTransform: 'capitalize',
                  marginBottom: -2,
                }}
              >
                {tab === 'transcript' ? '📝 Transcript' : tab === 'speakers' ? '👥 Speakers' : '🔑 Keywords'}
              </button>
            ))}
          </div>

          {/* Transcript Tab */}
          {activeTab === 'transcript' && (
            <div style={{ backgroundColor: '#fff', border: '1px solid #E5E7EB', borderRadius: 8, padding: 20 }}>
              {analysis.transcription?.error ? (
                <p style={{ color: '#DC2626' }}>{analysis.transcription.error}</p>
              ) : analysis.transcription?.text ? (
                <>
                  {analysis.transcription.confidence != null && (
                    <div style={{ fontSize: 12, color: '#6B7280', marginBottom: 12 }}>
                      Confidence: {(analysis.transcription.confidence * 100).toFixed(1)}%
                    </div>
                  )}
                  <p style={{ lineHeight: 1.8, fontSize: 15 }}>
                    {highlightKeywords(analysis.transcription.text, analysis.keywords || [])}
                  </p>
                </>
              ) : (
                <p style={{ color: '#9CA3AF' }}>No transcription available. Click "Analyze Audio" to generate.</p>
              )}
            </div>
          )}

          {/* Speakers Tab - Timeline */}
          {activeTab === 'speakers' && (
            <div style={{ backgroundColor: '#fff', border: '1px solid #E5E7EB', borderRadius: 8, padding: 20 }}>
              {analysis.speakers && analysis.speakers.length > 0 ? (
                <>
                  <div style={{ display: 'flex', gap: 16, marginBottom: 20, flexWrap: 'wrap' }}>
                    {analysis.speakers.map((speaker, idx) => (
                      <div key={speaker.id} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{
                          width: 14, height: 14, borderRadius: '50%',
                          backgroundColor: SPEAKER_COLORS[idx % SPEAKER_COLORS.length],
                        }} />
                        <span style={{ fontSize: 14, fontWeight: 500 }}>{speaker.label}</span>
                        <span style={{ fontSize: 12, color: '#6B7280' }}>
                          ({formatDuration(speaker.duration_seconds)})
                        </span>
                      </div>
                    ))}
                  </div>
                  {/* Timeline visualization */}
                  <div style={{ position: 'relative', height: 60, backgroundColor: '#F3F4F6', borderRadius: 8, overflow: 'hidden' }}>
                    {analysis.speakers.map((speaker, sIdx) =>
                      speaker.segments.map((seg, segIdx) => {
                        const totalDuration = analysis.duration?.estimated_seconds || 1;
                        const left = (seg.start / totalDuration) * 100;
                        const width = ((seg.end - seg.start) / totalDuration) * 100;
                        return (
                          <div
                            key={`${sIdx}-${segIdx}`}
                            title={`${speaker.label}: ${formatDuration(seg.start)} - ${formatDuration(seg.end)}`}
                            style={{
                              position: 'absolute', top: sIdx * 28 + 4, left: `${left}%`, width: `${Math.max(width, 0.5)}%`,
                              height: 22, backgroundColor: SPEAKER_COLORS[sIdx % SPEAKER_COLORS.length],
                              borderRadius: 4, opacity: 0.8, cursor: 'pointer',
                            }}
                          />
                        );
                      })
                    )}
                  </div>
                </>
              ) : (
                <p style={{ color: '#9CA3AF' }}>No speaker data available.</p>
              )}
            </div>
          )}

          {/* Keywords Tab */}
          {activeTab === 'keywords' && (
            <div style={{ backgroundColor: '#fff', border: '1px solid #E5E7EB', borderRadius: 8, padding: 20 }}>
              {analysis.keywords && analysis.keywords.length > 0 ? (
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
                  {analysis.keywords.map((kw, idx) => (
                    <div key={idx} style={{
                      display: 'flex', alignItems: 'center', gap: 8,
                      backgroundColor: '#FEF3C7', border: '1px solid #F59E0B',
                      borderRadius: 20, padding: '6px 14px',
                    }}>
                      <span style={{ fontWeight: 600, fontSize: 14 }}>{kw.keyword}</span>
                      <span style={{
                        backgroundColor: '#F59E0B', color: '#fff', borderRadius: '50%',
                        width: 22, height: 22, display: 'flex', alignItems: 'center',
                        justifyContent: 'center', fontSize: 12, fontWeight: 700,
                      }}>
                        {kw.count}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p style={{ color: '#9CA3AF' }}>No keywords detected. Configure keywords via AUDIO_KEYWORDS env var.</p>
              )}
            </div>
          )}
        </>
      )}

      {/* Previous Transcriptions List */}
      {transcriptions.length > 0 && (
        <div style={{ marginTop: 32 }}>
          <h3 style={{ fontSize: 18, fontWeight: 600, marginBottom: 16 }}>Previous Transcriptions</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {transcriptions.map(t => (
              <div key={t.id} style={{
                border: '1px solid #E5E7EB', borderRadius: 8, padding: 16, backgroundColor: '#fff',
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                  <span style={{ fontSize: 12, color: '#6B7280' }}>
                    Recording #{t.recording_id} • {new Date(t.created_at).toLocaleString()}
                  </span>
                  <span style={{
                    backgroundColor: '#EEF2FF', color: '#4338CA', padding: '1px 8px',
                    borderRadius: 10, fontSize: 12,
                  }}>
                    {LANGUAGE_LABELS[t.language] || t.language}
                  </span>
                </div>
                <p style={{ margin: 0, lineHeight: 1.6, fontSize: 14 }}>
                  {t.text.length > 200 ? t.text.substring(0, 200) + '...' : t.text}
                </p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default AudioIntelligence;
