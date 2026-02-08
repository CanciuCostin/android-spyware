import { createConsumer, type Consumer, type Subscription } from '@rails/actioncable';
import { ConnectionStatus, type WebSocketMessage } from '../types/api';

type MessageHandler = (message: WebSocketMessage) => void;
type ConnectionStatusHandler = (status: ConnectionStatus) => void;

export class WebSocketService {
  private cable: Consumer | null = null;
  private subscriptions: Map<string, Subscription> = new Map();
  private messageHandlers: Set<MessageHandler> = new Set();
  private statusHandlers: Set<ConnectionStatusHandler> = new Set();
  private connectionStatus: ConnectionStatus = ConnectionStatus.DISCONNECTED;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
  private heartbeatInterval: ReturnType<typeof setInterval> | null = null;
  private url: string;

  constructor(url?: string) {
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const defaultHost = import.meta.env.VITE_WS_URL || `${wsProtocol}//${window.location.host}/cable`;
    this.url = url || defaultHost;
  }

  connect(): void {
    if (this.cable) {
      console.warn('WebSocket already connected');
      return;
    }

    this.setStatus(ConnectionStatus.CONNECTING);

    try {
      this.cable = createConsumer(this.url);
      this.setupConnectionHandlers();
      this.startHeartbeat();
      console.log('WebSocket connecting to:', this.url);
    } catch (error) {
      console.error('Failed to create WebSocket connection:', error);
      this.setStatus(ConnectionStatus.ERROR);
      this.scheduleReconnect();
    }
  }

  disconnect(): void {
    this.stopHeartbeat();
    this.clearReconnectTimeout();

    if (this.cable) {
      this.subscriptions.forEach((sub) => sub.unsubscribe());
      this.subscriptions.clear();
      this.cable.disconnect();
      this.cable = null;
    }

    this.setStatus(ConnectionStatus.DISCONNECTED);
    this.reconnectAttempts = 0;
  }

  subscribe(channel: string, params?: Record<string, unknown>): Subscription | null {
    if (!this.cable) {
      console.error('Cannot subscribe: WebSocket not connected');
      return null;
    }

    if (this.subscriptions.has(channel)) {
      console.warn(`Already subscribed to ${channel}`);
      return this.subscriptions.get(channel)!;
    }

    const subscription = this.cable.subscriptions.create(
      { channel, ...params },
      {
        connected: () => {
          console.log(`Subscribed to ${channel}`);
          this.setStatus(ConnectionStatus.CONNECTED);
          this.reconnectAttempts = 0;
        },
        disconnected: () => {
          console.log(`Disconnected from ${channel}`);
          this.handleDisconnection();
        },
        received: (data: unknown) => {
          this.handleMessage(data as WebSocketMessage);
        },
        rejected: () => {
          console.error(`Subscription to ${channel} was rejected`);
          this.setStatus(ConnectionStatus.ERROR);
        },
      }
    );

    this.subscriptions.set(channel, subscription);
    return subscription;
  }

  unsubscribe(channel: string): void {
    const subscription = this.subscriptions.get(channel);
    if (subscription) {
      subscription.unsubscribe();
      this.subscriptions.delete(channel);
      console.log(`Unsubscribed from ${channel}`);
    }
  }

  send(channel: string, action: string, data?: object): void {
    const subscription = this.subscriptions.get(channel);
    if (!subscription) {
      console.error(`Cannot send to ${channel}: not subscribed`);
      return;
    }

    subscription.perform(action, data);
  }

  onMessage(handler: MessageHandler): () => void {
    this.messageHandlers.add(handler);
    return () => this.messageHandlers.delete(handler);
  }

  onStatusChange(handler: ConnectionStatusHandler): () => void {
    this.statusHandlers.add(handler);
    handler(this.connectionStatus); // Call immediately with current status
    return () => this.statusHandlers.delete(handler);
  }

  getStatus(): ConnectionStatus {
    return this.connectionStatus;
  }

  isConnected(): boolean {
    return this.connectionStatus === ConnectionStatus.CONNECTED;
  }

  private setupConnectionHandlers(): void {
    if (!this.cable) return;

    // ActionCable doesn't expose connection events directly,
    // so we rely on subscription callbacks
  }

  private handleMessage(message: WebSocketMessage): void {
    this.messageHandlers.forEach((handler) => {
      try {
        handler(message);
      } catch (error) {
        console.error('Error in message handler:', error);
      }
    });
  }

  private handleDisconnection(): void {
    if (this.connectionStatus === ConnectionStatus.DISCONNECTED) {
      return; // Already handling disconnection
    }

    this.setStatus(ConnectionStatus.DISCONNECTED);
    this.scheduleReconnect();
  }

  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      this.setStatus(ConnectionStatus.ERROR);
      return;
    }

    this.clearReconnectTimeout();
    this.setStatus(ConnectionStatus.RECONNECTING);

    const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
    this.reconnectAttempts++;

    console.log(`Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

    this.reconnectTimeout = setTimeout(() => {
      console.log('Attempting to reconnect...');
      this.disconnect();
      this.connect();
    }, delay);
  }

  private clearReconnectTimeout(): void {
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatInterval = setInterval(() => {
      // Send heartbeat to all subscriptions
      this.subscriptions.forEach((_, channel) => {
        this.send(channel, 'heartbeat', { timestamp: Date.now() });
      });
    }, 30000); // Every 30 seconds
  }

  private stopHeartbeat(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  private setStatus(status: ConnectionStatus): void {
    if (this.connectionStatus === status) return;

    this.connectionStatus = status;
    console.log('WebSocket status:', status);

    this.statusHandlers.forEach((handler) => {
      try {
        handler(status);
      } catch (error) {
        console.error('Error in status handler:', error);
      }
    });
  }
}

// Singleton instance
let instance: WebSocketService | null = null;

export function getWebSocketService(): WebSocketService {
  if (!instance) {
    instance = new WebSocketService();
  }
  return instance;
}

export function resetWebSocketService(): void {
  if (instance) {
    instance.disconnect();
    instance = null;
  }
}
