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
                  {msg.type === 'table' && msg.data && (
                    <div className="mt-2 p-2 bg-black/20 rounded border border-white/5 overflow-x-auto text-[10px]">
                      <table className="w-full">
                        <thead>
                          <tr className="border-b border-white/10">
                            {Object.keys(msg.data[0] || {}).map((k) => (
                              <th key={k} className="text-left p-1 uppercase opacity-60">
                                {k}
                              </th>
                            ))}
                          </tr>
                        </thead>
                        <tbody>
                          {msg.data.slice(0, 5).map((row: any, j: number) => (
                            <tr key={j} className="border-b border-white/5 last:border-0">
                              {Object.values(row).map((v: any, k) => (
                                <td key={k} className="p-1 truncate max-w-[100px]">
                                  {String(v)}
                                </td>
                              ))}
                            </tr>
                          ))}
                        </tbody>
                      </table>
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
