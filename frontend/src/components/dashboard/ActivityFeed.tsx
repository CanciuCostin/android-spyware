import React from 'react';
import { Card, CardContent } from '../ui';
import { Badge } from '../ui/Badge';
import {
  Activity,
  Terminal,
  Smartphone,
  Download,
  AlertCircle,
  CheckCircle,
  Clock,
} from 'lucide-react';
import type { Command } from '../../types/api';
import { CommandStatus, CommandType } from '../../types/api';
import { formatDistanceToNow } from '../../utils/dateUtils';

export interface ActivityEvent {
  id: string;
  type: 'device_connect' | 'device_disconnect' | 'command_executed' | 'data_received' | 'error';
  title: string;
  description: string;
  timestamp: string;
  metadata?: Record<string, unknown>;
}

export interface ActivityFeedProps {
  commands?: Command[];
  events?: ActivityEvent[];
  maxItems?: number;
  loading?: boolean;
  onEventClick?: (event: ActivityEvent) => void;
}

export const ActivityFeed: React.FC<ActivityFeedProps> = ({
  commands = [],
  events = [],
  maxItems = 10,
  loading = false,
  onEventClick,
}) => {
  const getEventIcon = (type: string) => {
    switch (type) {
      case 'device_connect':
        return <Smartphone size={18} className="text-neon-400" />;
      case 'device_disconnect':
        return <Smartphone size={18} className="text-red-400" />;
      case 'command_executed':
        return <Terminal size={18} className="text-cyber-400" />;
      case 'data_received':
        return <Download size={18} className="text-electric-400" />;
      case 'error':
        return <AlertCircle size={18} className="text-red-400" />;
      default:
        return <Activity size={18} className="text-white/40" />;
    }
  };

  const getCommandIcon = (type: CommandType) => {
    switch (type) {
      case CommandType.SCREENSHOT:
      case CommandType.CAMERA:
        return <Download size={18} className="text-electric-400" />;
      case CommandType.SHELL:
        return <Terminal size={18} className="text-cyber-400" />;
      default:
        return <Activity size={18} className="text-white/40" />;
    }
  };

  const getCommandStatusBadge = (status: CommandStatus) => {
    switch (status) {
      case CommandStatus.COMPLETED:
        return (
          <Badge variant="success" size="sm">
            <CheckCircle size={12} className="mr-1" />
            Completed
          </Badge>
        );
      case CommandStatus.FAILED:
        return (
          <Badge variant="danger" size="sm">
            <AlertCircle size={12} className="mr-1" />
            Failed
          </Badge>
        );
      case CommandStatus.EXECUTING:
        return (
          <Badge variant="info" size="sm">
            <Clock size={12} className="mr-1" />
            Running
          </Badge>
        );
      case CommandStatus.PENDING:
        return (
          <Badge variant="warning" size="sm">
            <Clock size={12} className="mr-1" />
            Pending
          </Badge>
        );
      default:
        return null;
    }
  };

  const formatTimestamp = (timestamp: string) => {
    try {
      return formatDistanceToNow(new Date(timestamp), { addSuffix: true });
    } catch {
      return 'Unknown';
    }
  };

  // Convert commands to activity events
  const commandEvents: ActivityEvent[] = commands.slice(0, maxItems).map((command) => ({
    id: command.id,
    type: 'command_executed',
    title: `Command: ${command.type}`,
    description: `Status: ${command.status}`,
    timestamp: command.updatedAt,
    metadata: { command },
  }));

  // Merge and sort all events
  const allEvents = [...events, ...commandEvents]
    .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
    .slice(0, maxItems);

  if (loading) {
    return (
      <Card variant="glass">
        <CardContent className="p-6">
          <div className="space-y-4">
            {[...Array(5)].map((_, i) => (
              <div key={i} className="flex gap-4 animate-pulse">
                <div className="w-10 h-10 bg-white/10 rounded-full"></div>
                <div className="flex-1">
                  <div className="h-4 bg-white/10 rounded w-3/4 mb-2"></div>
                  <div className="h-3 bg-white/10 rounded w-1/2"></div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card variant="glass">
      <div className="p-6 border-b border-white/10">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white flex items-center gap-2">
            <Activity size={20} aria-hidden="true" />
            Recent Activity
          </h2>
          <Badge variant="default" aria-label={`${allEvents.length} recent events`}>{allEvents.length}</Badge>
        </div>
      </div>
      <CardContent className="p-6">
        {allEvents.length === 0 ? (
          <div className="text-center py-8">
            <Activity size={48} className="mx-auto mb-4 text-white/20" aria-hidden="true" />
            <p className="text-white/40">No recent activity</p>
          </div>
        ) : (
          <div className="space-y-4" role="feed" aria-label="Activity feed" aria-busy={loading}>
            {allEvents.map((event, index) => {
              const command = event.metadata?.command as Command | undefined;

              return (
                <article
                  key={event.id}
                  className="flex gap-4 pb-4 border-b border-white/5 last:border-0 cursor-pointer hover:bg-white/5 -mx-2 px-2 py-2 rounded transition-colors animate-fade-in"
                  style={{ animationDelay: `${index * 50}ms` }}
                  onClick={() => onEventClick?.(event)}
                  role="article"
                  aria-label={`${event.title} - ${event.description}`}
                  tabIndex={onEventClick ? 0 : undefined}
                  onKeyDown={(e) => {
                    if (onEventClick && (e.key === 'Enter' || e.key === ' ')) {
                      e.preventDefault();
                      onEventClick(event);
                    }
                  }}
                >
                  {/* Icon */}
                  <div className="flex-shrink-0" aria-hidden="true">
                    <div className="w-10 h-10 bg-white/5 rounded-full flex items-center justify-center">
                      {command ? getCommandIcon(command.type) : getEventIcon(event.type)}
                    </div>
                  </div>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between gap-4 mb-1">
                      <h4 className="text-sm font-medium text-white truncate">{event.title}</h4>
                      {command && getCommandStatusBadge(command.status)}
                    </div>
                    <p className="text-xs text-white/50 mb-1">{event.description}</p>
                    <time className="text-xs text-white/30" dateTime={event.timestamp}>
                      {formatTimestamp(event.timestamp)}
                    </time>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
};
