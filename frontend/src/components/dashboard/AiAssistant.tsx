import React, { useState, useRef, useEffect } from 'react';
import { Bot, Send, X, Minimize2, Maximize2, Sparkles } from 'lucide-react';
import { apiService } from '../../services/api';
import { FadeIn } from '../animations';

interface Message {
  role: 'user' | 'assistant';
  content: string;
  type?: string;
  data?: any;
  timestamp: string;
}

export const AiAssistant: React.FC<{ deviceId?: string }> = ({ deviceId }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [isMinimized, setIsMinimized] = useState(false);
  const [input, setInput] = useState('');
  const [messages, setMessages] = useState<Message[]>([
    {
      role: 'assistant',
      content: "Hello! I'm your EagleSpy AI assistant. How can I help you analyze device data today?",
      timestamp: new Date().toISOString(),
    },
  ]);
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim() || isLoading) return;

    const userMessage: Message = {
      role: 'user',
      content: input,
      timestamp: new Date().toISOString(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    try {
      const response = await apiService.post<any>('/ai/chat', {
        message: input,
        device_id: deviceId,
        history: messages.slice(-5),
      });

      const assistantMessage: Message = {
        role: 'assistant',
        content: response.content,
        type: response.type,
        data: response.data,
        timestamp: new Date().toISOString(),
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch (error: any) {
      setMessages((prev) => [
        ...prev,
        {
          role: 'assistant',
          content: `Error: ${error.message || 'Failed to get response'}`,
          timestamp: new Date().toISOString(),
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-6 right-6 p-4 bg-electric-500 text-white rounded-full shadow-lg hover:bg-electric-600 transition-all transform hover:scale-110 glow-electric z-50"
      >
        <Bot size={24} />
      </button>
    );
  }

  return (
    <div
      className={`fixed bottom-6 right-6 w-96 bg-slate-900 border border-white/10 rounded-2xl shadow-2xl flex flex-col z-50 transition-all ${
        isMinimized ? 'h-14' : 'h-[500px]'
      }`}
    >
      {/* Header */}
      <div className="p-4 border-b border-white/10 flex items-center justify-between bg-white/5 rounded-t-2xl">
        <div className="flex items-center gap-2">
          <Sparkles size={18} className="text-electric-400" />
          <span className="font-bold text-white">AI Command Assistant</span>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsMinimized(!isMinimized)}
            className="p-1 hover:bg-white/10 rounded text-white/60 hover:text-white"
          >
            {isMinimized ? <Maximize2 size={16} /> : <Minimize2 size={16} />}
          </button>
          <button
            onClick={() => setIsOpen(false)}
            className="p-1 hover:bg-white/10 rounded text-white/60 hover:text-white"
          >
            <X size={16} />
          </button>
        </div>
      </div>

      {!isMinimized && (
        <>
          {/* Messages */}
          <div className="flex-1 overflow-y-auto p-4 space-y-4 scrollbar-thin scrollbar-thumb-white/10">
            {messages.map((msg, i) => (
              <div
                key={i}
                className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-[85%] p-3 rounded-2xl text-sm ${
                    msg.role === 'user'
                      ? 'bg-electric-500 text-white'
                      : 'bg-white/10 text-white/90 border border-white/5'
                  }`}
                >
                  <p className="whitespace-pre-wrap">{msg.content}</p>
                  
                  {/* Table Visualization */}
                  {msg.type === 'table' && msg.data && Array.isArray(msg.data) && (
                    <div className="mt-2 p-0 bg-black/40 rounded-lg border border-white/10 overflow-hidden text-[11px]">
                      <div className="max-h-60 overflow-y-auto overflow-x-auto scrollbar-thin scrollbar-thumb-white/20">
                        <table className="w-full border-collapse">
                          <thead className="sticky top-0 bg-slate-800 z-10 shadow-md">
                            <tr className="border-b border-white/20">
                              {Object.keys(msg.data[0] || {}).map((k) => (
                                <th key={k} className="text-left p-2 uppercase font-bold text-electric-400 whitespace-nowrap">
                                  {k.replace(/_/g, ' ')}
                                </th>
                              ))}
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-white/5">
                            {msg.data.map((row: any, j: number) => (
                              <tr key={j} className="hover:bg-white/5 transition-colors">
                                {Object.values(row).map((v: any, k) => (
                                  <td key={k} className="p-2 break-words min-w-[80px]">
                                    {v === null || v === undefined ? '-' : String(v)}
                                  </td>
                                ))}
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                      {msg.data.length > 5 && (
                        <div className="p-1.5 bg-white/5 text-[9px] text-center opacity-50 italic">
                          Showing {msg.data.length} entries
                        </div>
                      )}
                    </div>
                  )}

                  {/* Chart/Bar Visualization Placeholder */}
                  {(msg.type === 'chart' || msg.type === 'bar_chart') && (
                    <div className="mt-2 p-3 bg-black/20 rounded border border-white/5 flex items-center justify-center h-24">
                      <div className="flex items-end gap-1 h-full">
                        {[40, 70, 30, 90, 50].map((h, idx) => (
                          <div 
                            key={idx} 
                            className="w-2 bg-electric-500 rounded-t" 
                            style={{ height: `${h}%` }} 
                          />
                        ))}
                      </div>
                      <span className="ml-3 text-[10px] opacity-60">Visualization Loaded</span>
                    </div>
                  )}

                  {/* Map Visualization Placeholder */}
                  {msg.type === 'map' && (
                    <div className="mt-2 p-2 bg-black/20 rounded border border-white/5 h-32 relative overflow-hidden">
                      <div className="absolute inset-0 bg-slate-800 opacity-50 flex items-center justify-center">
                        <span className="text-[10px]">MAP VIEW: {msg.data?.length || 0} points</span>
                      </div>
                      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2">
                        <div className="w-3 h-3 bg-red-500 rounded-full animate-ping" />
                      </div>
                    </div>
                  )}

                  {/* Alert/Risk Visualization */}
                  {msg.type === 'alert' && msg.data && (
                    <div className="mt-2 p-3 bg-red-500/10 border border-red-500/50 rounded-xl flex items-start gap-3">
                      <div className="mt-1 w-2 h-2 bg-red-500 rounded-full animate-pulse" />
                      <div className="flex-1">
                        <div className="text-xs font-bold text-red-400 uppercase mb-1">Security Alert</div>
                        <div className="text-sm text-white/90">{msg.content}</div>
                        {msg.data.factors && (
                          <div className="mt-2 flex flex-wrap gap-1">
                            {msg.data.factors.map((f: any, idx: number) => (
                              <span key={idx} className="px-2 py-0.5 bg-red-500/20 text-[10px] rounded text-red-300">
                                {f.type || f}
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            ))}
            {isLoading && (
              <div className="flex justify-start">
                <div className="bg-white/10 p-3 rounded-2xl flex gap-1">
                  <div className="w-1.5 h-1.5 bg-electric-400 rounded-full animate-bounce" />
                  <div className="w-1.5 h-1.5 bg-electric-400 rounded-full animate-bounce [animation-delay:0.2s]" />
                  <div className="w-1.5 h-1.5 bg-electric-400 rounded-full animate-bounce [animation-delay:0.4s]" />
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          {/* Input */}
          <div className="p-4 border-t border-white/10">
            <div className="flex gap-2">
              <input
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSend()}
                placeholder="Ask about device data..."
                className="flex-1 bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-white placeholder:text-white/30 focus:outline-none focus:border-electric-500 transition-colors text-sm"
              />
              <button
                onClick={handleSend}
                disabled={isLoading || !input.trim()}
                className="p-2 bg-electric-500 text-white rounded-xl hover:bg-electric-600 disabled:opacity-50 disabled:hover:bg-electric-500 transition-all"
              >
                <Send size={20} />
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
};
