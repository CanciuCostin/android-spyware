import React from 'react';
import { Card, CardHeader, CardTitle } from '../ui';
import { CommandPanel } from './CommandPanel';

interface CommandTabProps {
  deviceId: string;
}

export const CommandTab: React.FC<CommandTabProps> = ({ deviceId }) => {
  return (
    <div className="space-y-6">
      <Card variant="glass">
        <CardHeader>
          <CardTitle>Command Execution</CardTitle>
        </CardHeader>
      </Card>

      <CommandPanel deviceId={deviceId} />
    </div>
  );
};
