// API Response Types
export interface ApiResponse<T> {
  data: T;
  success: boolean;
  error?: string;
  message?: string;
}

// Device Types
export interface Device {
  id: string;
  name: string;
  model: string;
  manufacturer: string;
  androidVersion: string;
  status: DeviceStatus;
  lastSeen: string;
  ipAddress?: string;
  batteryLevel?: number;
  isCharging?: boolean;
  location?: DeviceLocation;
  metadata?: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export const DeviceStatus = {
  ONLINE: 'online',
  OFFLINE: 'offline',
  IDLE: 'idle',
  BUSY: 'busy',
  ERROR: 'error',
} as const;
export type DeviceStatus = typeof DeviceStatus[keyof typeof DeviceStatus];

export interface DeviceLocation {
  latitude: number;
  longitude: number;
  accuracy?: number;
  timestamp?: string;
}

// Command Types
export interface Command {
  id: string;
  deviceId: string;
  type: CommandType;
  payload?: Record<string, unknown>;
  status: CommandStatus;
  result?: CommandResult;
  createdAt: string;
  updatedAt: string;
  executedAt?: string;
}

export const CommandType = {
  SHELL: 'shell',
  SCREENSHOT: 'screenshot',
  CAMERA: 'camera',
  MICROPHONE: 'microphone',
  CONTACTS: 'contacts',
  MESSAGES: 'messages',
  CALL_LOG: 'call_log',
  LOCATION: 'location',
  FILES: 'files',
  INSTALL_APP: 'install_app',
  UNINSTALL_APP: 'uninstall_app',
  REBOOT: 'reboot',
  WEBCAM_START: 'webcam_start',
  WEBCAM_STOP: 'webcam_stop',
  CUSTOM: 'custom',
} as const;
export type CommandType = typeof CommandType[keyof typeof CommandType];

export const CommandStatus = {
  PENDING: 'pending',
  SENT: 'sent',
  EXECUTING: 'executing',
  COMPLETED: 'completed',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
} as const;
export type CommandStatus = typeof CommandStatus[keyof typeof CommandStatus];

export interface CommandResult {
  success: boolean;
  data?: unknown;
  error?: string;
  output?: string;
  timestamp?: string;
}

// WebSocket Message Types
export interface WebSocketMessage {
  type: WebSocketMessageType;
  payload: unknown;
  timestamp?: string;
}

export const WebSocketMessageType = {
  DEVICE_CONNECTED: 'device_connected',
  DEVICE_DISCONNECTED: 'device_disconnected',
  DEVICE_STATUS_UPDATED: 'device_status_updated',
  COMMAND_RECEIVED: 'command_received',
  COMMAND_COMPLETED: 'command_completed',
  COMMAND_FAILED: 'command_failed',
  NOTIFICATION: 'notification',
  ERROR: 'error',
  HEARTBEAT: 'heartbeat',
} as const;
export type WebSocketMessageType = typeof WebSocketMessageType[keyof typeof WebSocketMessageType];

export interface DeviceStatusMessage {
  deviceId: string;
  status: DeviceStatus;
  metadata?: Partial<Device>;
}

export interface CommandStatusMessage {
  commandId: string;
  status: CommandStatus;
  result?: CommandResult;
}

export interface NotificationMessage {
  level: 'info' | 'warning' | 'error' | 'success';
  message: string;
  title?: string;
  duration?: number;
}

// Connection Status
export const ConnectionStatus = {
  CONNECTING: 'connecting',
  CONNECTED: 'connected',
  DISCONNECTED: 'disconnected',
  RECONNECTING: 'reconnecting',
  ERROR: 'error',
} as const;
export type ConnectionStatus = typeof ConnectionStatus[keyof typeof ConnectionStatus];

// API Request Types
export interface SendCommandRequest {
  deviceId: string;
  type: CommandType;
  payload?: Record<string, unknown>;
}

export interface DeviceQuery {
  status?: DeviceStatus;
  search?: string;
  limit?: number;
  offset?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

export interface CommandQuery {
  deviceId?: string;
  status?: CommandStatus;
  type?: CommandType;
  limit?: number;
  offset?: number;
}
