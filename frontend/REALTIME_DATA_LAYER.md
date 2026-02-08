# Real-time Data Layer Documentation

## Overview

The real-time data layer provides WebSocket-based communication with the Rails backend, state management using Zustand, and React hooks for seamless integration.

## Architecture

```
┌─────────────────┐
│  React Components │
└────────┬─────────┘
         │
         │ uses
         ↓
┌─────────────────┐
│  Custom Hooks    │  ← useDevices, useCommand, useRealtime
└────────┬─────────┘
         │
         │ accesses
         ↓
┌─────────────────┐
│  Zustand Stores  │  ← deviceStore, commandStore, uiStore
└────────┬─────────┘
         │
         │ uses
         ↓
┌─────────────────┐
│    Services      │  ← WebSocket, API
└─────────────────┘
         │
         │ connects to
         ↓
┌─────────────────┐
│  Rails Backend   │
└─────────────────┘
```

## Services

### WebSocket Service (`src/services/websocket.ts`)

Manages ActionCable WebSocket connection with the Rails backend.

**Features:**
- Auto-reconnect with exponential backoff
- Connection status tracking
- Channel subscription management
- Heartbeat mechanism
- Message broadcasting to subscribers

**Usage:**
```typescript
import { getWebSocketService } from './services/websocket';

const ws = getWebSocketService();
ws.connect();

// Subscribe to a channel
ws.subscribe('DevicesChannel');

// Listen to messages
ws.onMessage((message) => {
  console.log('Received:', message);
});

// Send data to channel
ws.send('DevicesChannel', 'update_status', { status: 'online' });
```

### API Service (`src/services/api.ts`)

HTTP client for REST API communication.

**Features:**
- Axios-based HTTP client
- Authentication token management
- CSRF token handling
- Request/response interceptors
- Error handling and formatting
- Type-safe endpoints

**Usage:**
```typescript
import { getApiService } from './services/api';

const api = getApiService();

// Set auth token
api.setAuthToken('your-token');

// Fetch devices
const response = await api.getDevices({ status: 'online' });

// Send command
const command = await api.sendCommand({
  deviceId: 'device-123',
  type: CommandType.SHELL,
  payload: { command: 'ls -la' }
});
```

## Stores

### Device Store (`src/stores/deviceStore.ts`)

Manages device state and real-time updates.

**State:**
- `devices`: Map of device objects
- `loading`: Loading state
- `error`: Error message
- `selectedDeviceId`: Currently selected device

**Actions:**
- `fetchDevices()`: Fetch all devices from API
- `addDevice(device)`: Add a new device
- `updateDevice(id, updates)`: Update device properties
- `removeDevice(id)`: Remove a device
- `setDeviceStatus(id, status)`: Update device status
- `selectDevice(id)`: Select a device

**WebSocket Integration:**
Automatically handles device connection/disconnection events.

### Command Store (`src/stores/commandStore.ts`)

Manages command execution and history.

**State:**
- `commands`: Map of command objects
- `pendingCommands`: Set of pending command IDs
- `loading`: Loading state
- `error`: Error message

**Actions:**
- `sendCommand(request)`: Send command with optimistic update
- `cancelCommand(id)`: Cancel a command
- `fetchCommands(deviceId?)`: Fetch command history
- `updateCommand(id, updates)`: Update command properties

**Optimistic Updates:**
Commands are added to the store immediately, then updated with server response.
If the request fails, the optimistic command is rolled back.

### UI Store (`src/stores/uiStore.ts`)

Manages UI state, notifications, and connection status.

**State:**
- `connectionStatus`: WebSocket connection status
- `notifications`: Array of notification objects
- `loading`: Map of loading states by key
- `errors`: Map of error messages by key

**Actions:**
- `addNotification(notification)`: Add a notification
- `removeNotification(id)`: Remove a notification
- `setLoading(key, loading)`: Set loading state
- `setError(key, error)`: Set error state

## Hooks

### useWebSocket

Manages WebSocket connection lifecycle.

```typescript
const { isConnected, status, subscribe, send } = useWebSocket();

// Subscribe to a channel
useEffect(() => {
  subscribe('DevicesChannel');
}, [subscribe]);
```

### useDevices

Fetches and manages device list with real-time updates.

```typescript
const { devices, loading, error, refresh } = useDevices();

// Devices are automatically updated via WebSocket
```

### useDevice

Manages a single device by ID.

```typescript
const { device, loading, update, refresh } = useDevice(deviceId);

// Update device
update({ name: 'New Name' });
```

### useCommand

Execute commands with optimistic updates.

```typescript
const { execute, cancel, loading, error } = useCommand();

// Execute a command
const command = await execute(deviceId, CommandType.SHELL, {
  command: 'ls -la'
});

// Cancel a command
await cancel(commandId);
```

### useCommands

Fetch command history for a device.

```typescript
const { commands, loading, refresh } = useCommands(deviceId);
```

### useRealtime

Monitor connection status and handle real-time notifications.

```typescript
const { isConnected, status } = useRealtime();
```

### useRealtimeUpdates

Listen to specific WebSocket message types.

```typescript
useRealtimeUpdates(WebSocketMessageType.DEVICE_CONNECTED, (payload) => {
  console.log('Device connected:', payload);
});
```

## Types

All TypeScript types are defined in `src/types/api.ts`.

**Core Types:**
- `Device`: Device information and status
- `Command`: Command execution details
- `ApiResponse<T>`: Generic API response wrapper
- `WebSocketMessage`: WebSocket message structure

**Enums:**
- `DeviceStatus`: online, offline, idle, busy, error
- `CommandType`: shell, screenshot, camera, etc.
- `CommandStatus`: pending, sent, executing, completed, failed
- `ConnectionStatus`: connecting, connected, disconnected, reconnecting, error

## Demo Component

See `src/components/RealtimeDemo.tsx` for a complete example.

The demo includes:
- Connection status display
- Device list with real-time updates
- Command execution
- Notification display

## Environment Variables

Add to your `.env` file:

```env
VITE_API_URL=http://localhost:3000/api
VITE_WS_URL=ws://localhost:3000/cable
```

## Usage Example

```typescript
import { useDevices, useCommand } from './hooks';

function DeviceControl() {
  const { devices, loading } = useDevices();
  const { execute } = useCommand();

  const handleCommand = async (deviceId: string) => {
    const result = await execute(deviceId, CommandType.SCREENSHOT);
    if (result) {
      console.log('Screenshot taken!');
    }
  };

  return (
    <div>
      {loading ? (
        <p>Loading...</p>
      ) : (
        devices.map(device => (
          <div key={device.id}>
            <h3>{device.name}</h3>
            <button onClick={() => handleCommand(device.id)}>
              Take Screenshot
            </button>
          </div>
        ))
      )}
    </div>
  );
}
```

## Testing

To test the real-time data layer:

1. Start the Rails backend
2. Start the frontend dev server
3. Navigate to `/demo` to see the RealtimeDemo component
4. Connect an Android device to see real-time updates

## Error Handling

The layer implements comprehensive error handling:

1. **API Errors**: Intercepted and formatted with proper messages
2. **WebSocket Disconnections**: Auto-reconnect with exponential backoff
3. **Optimistic Update Failures**: Automatic rollback
4. **Network Errors**: User-friendly error messages

## Performance Considerations

- **WebSocket Connection**: Single persistent connection for all real-time updates
- **Store Updates**: Zustand provides efficient re-renders
- **Optimistic Updates**: Immediate UI feedback without waiting for server
- **Message Batching**: WebSocket service batches multiple updates

## Future Enhancements

- [ ] Add request retry mechanism
- [ ] Implement message queue for offline support
- [ ] Add WebSocket message compression
- [ ] Implement pagination for large device lists
- [ ] Add caching layer for API responses
