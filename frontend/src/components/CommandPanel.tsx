import React, { useState } from 'react';
import { Card, CardHeader, CardTitle, CardContent, Input, Button } from './ui';

export interface CommandPanelProps {
  deviceId?: string;
  onExecute: (command: string) => Promise<void>;
  commandHistory?: string[];
}

export const CommandPanel: React.FC<CommandPanelProps> = ({
  deviceId,
  onExecute,
  commandHistory = [],
}) => {
  const [command, setCommand] = useState('');
  const [isExecuting, setIsExecuting] = useState(false);
  const [output, setOutput] = useState<string[]>([]);

  const handleExecute = async () => {
    if (!command.trim()) return;

    setIsExecuting(true);
    try {
      await onExecute(command);
      setOutput((prev) => [...prev, `$ ${command}`, 'Command executed successfully']);
      setCommand('');
    } catch (error) {
      setOutput((prev) => [...prev, `$ ${command}`, `Error: ${error}`]);
    } finally {
      setIsExecuting(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleExecute();
    }
  };

  const quickCommands = [
    { label: 'Get Location', command: 'get_location' },
    { label: 'Take Photo', command: 'take_photo' },
    { label: 'Record Audio', command: 'record_audio' },
    { label: 'List Contacts', command: 'list_contacts' },
  ];

  return (
    <Card variant="dark">
      <CardHeader>
        <CardTitle>Command Panel</CardTitle>
        {deviceId && <p className="text-sm text-white/60 mt-1">Device: {deviceId}</p>}
      </CardHeader>

      <CardContent>
        {/* Output Terminal */}
        <div className="mb-4 p-4 rounded-lg bg-dark-950 border border-white/10 h-48 overflow-y-auto custom-scrollbar font-mono text-sm">
          {output.length === 0 ? (
            <p className="text-white/40">No output yet. Execute a command to see results.</p>
          ) : (
            output.map((line, idx) => (
              <div key={idx} className={line.startsWith('$') ? 'text-electric-400' : 'text-white/80'}>
                {line}
              </div>
            ))
          )}
        </div>

        {/* Quick Commands */}
        <div className="mb-4">
          <p className="text-sm text-white/60 mb-2">Quick Commands:</p>
          <div className="grid grid-cols-2 gap-2">
            {quickCommands.map((cmd) => (
              <Button
                key={cmd.command}
                variant="ghost"
                size="sm"
                onClick={() => setCommand(cmd.command)}
                disabled={isExecuting}
              >
                {cmd.label}
              </Button>
            ))}
          </div>
        </div>

        {/* Command Input */}
        <div className="flex gap-2">
          <Input
            value={command}
            onChange={(e) => setCommand(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Enter command..."
            className="flex-1 font-mono"
            disabled={isExecuting}
          />
          <Button onClick={handleExecute} isLoading={isExecuting} disabled={!command.trim()}>
            Execute
          </Button>
        </div>

        {/* Command History */}
        {commandHistory.length > 0 && (
          <div className="mt-4">
            <p className="text-sm text-white/60 mb-2">Recent Commands:</p>
            <div className="space-y-1">
              {commandHistory.slice(-5).map((cmd, idx) => (
                <button
                  key={idx}
                  onClick={() => setCommand(cmd)}
                  className="block w-full text-left px-3 py-1 rounded text-sm text-white/60 hover:text-white hover:bg-white/5 transition-colors font-mono"
                >
                  {cmd}
                </button>
              ))}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
};
