import { create } from 'zustand';
import type { Device, WebSocketMessage } from '../types/api';
import { DeviceStatus, WebSocketMessageType } from '../types/api';
import { getWebSocketService } from '../services/websocket';
import { getApiService } from '../services/api';

interface DeviceState {
  devices: Map<string, Device>;
  loading: boolean;
  error: string | null;
  selectedDeviceId: string | null;
}

interface DeviceActions {
  // Fetch devices from API
  fetchDevices: () => Promise<void>;
  fetchDevice: (id: string) => Promise<void>;

  // CRUD operations
  addDevice: (device: Device) => void;
  updateDevice: (id: string, updates: Partial<Device>) => void;
  removeDevice: (id: string) => void;
  setDeviceStatus: (id: string, status: DeviceStatus) => void;

  // Selection
  selectDevice: (id: string | null) => void;
  getSelectedDevice: () => Device | null;

  // Utilities
  getDevice: (id: string) => Device | undefined;
  getDevicesList: () => Device[];
  getOnlineDevices: () => Device[];
  clearError: () => void;

  // WebSocket integration
  handleWebSocketMessage: (message: WebSocketMessage) => void;
}

type DeviceStore = DeviceState & DeviceActions;

export const useDeviceStore = create<DeviceStore>((set, get) => ({
  // Initial state
  devices: new Map(),
  loading: false,
  error: null,
  selectedDeviceId: null,

  // Fetch devices from API
  fetchDevices: async () => {
    set({ loading: true, error: null });
    try {
      const api = getApiService();
      const response = await api.getDevices();

      if (response.success && response.data) {
        const devicesMap = new Map<string, Device>();
        response.data.forEach((device) => {
          devicesMap.set(device.id, device);
        });
        set({ devices: devicesMap, loading: false });
      } else {
        set({ error: response.error || 'Failed to fetch devices', loading: false });
      }
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to fetch devices',
        loading: false,
      });
    }
  },

  fetchDevice: async (id: string) => {
    set({ loading: true, error: null });
    try {
      const api = getApiService();
      const response = await api.getDevice(id);

      if (response.success && response.data) {
        set((state) => {
          const newDevices = new Map(state.devices);
          newDevices.set(id, response.data);
          return { devices: newDevices, loading: false };
        });
      } else {
        set({ error: response.error || 'Failed to fetch device', loading: false });
      }
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to fetch device',
        loading: false,
      });
    }
  },

  // Add a new device
  addDevice: (device: Device) => {
    set((state) => {
      const newDevices = new Map(state.devices);
      newDevices.set(device.id, device);
      return { devices: newDevices };
    });
  },

  // Update device with partial data
  updateDevice: (id: string, updates: Partial<Device>) => {
    set((state) => {
      const device = state.devices.get(id);
      if (!device) return state;

      const newDevices = new Map(state.devices);
      newDevices.set(id, { ...device, ...updates, updatedAt: new Date().toISOString() });
      return { devices: newDevices };
    });
  },

  // Remove a device
  removeDevice: (id: string) => {
    set((state) => {
      const newDevices = new Map(state.devices);
      newDevices.delete(id);
      return {
        devices: newDevices,
        selectedDeviceId: state.selectedDeviceId === id ? null : state.selectedDeviceId,
      };
    });
  },

  // Update device status
  setDeviceStatus: (id: string, status: DeviceStatus) => {
    get().updateDevice(id, { status, lastSeen: new Date().toISOString() });
  },

  // Select a device
  selectDevice: (id: string | null) => {
    set({ selectedDeviceId: id });
  },

  // Get selected device
  getSelectedDevice: () => {
    const state = get();
    if (!state.selectedDeviceId) return null;
    return state.devices.get(state.selectedDeviceId) || null;
  },

  // Get a specific device
  getDevice: (id: string) => {
    return get().devices.get(id);
  },

  // Get all devices as array
  getDevicesList: () => {
    return Array.from(get().devices.values());
  },

  // Get online devices
  getOnlineDevices: () => {
    return Array.from(get().devices.values()).filter(
      (device) => device.status === DeviceStatus.ONLINE
    );
  },

  // Clear error
  clearError: () => {
    set({ error: null });
  },

  // Handle WebSocket messages
  handleWebSocketMessage: (message: WebSocketMessage) => {
    const { type, payload } = message;

    switch (type) {
      case WebSocketMessageType.DEVICE_CONNECTED: {
        const device = payload as Device;
        get().addDevice(device);
        console.log('Device connected:', device.id);
        break;
      }

      case WebSocketMessageType.DEVICE_DISCONNECTED: {
        const { deviceId } = payload as { deviceId: string };
        get().setDeviceStatus(deviceId, DeviceStatus.OFFLINE);
        console.log('Device disconnected:', deviceId);
        break;
      }

      case WebSocketMessageType.DEVICE_STATUS_UPDATED: {
        const { deviceId, status, metadata } = payload as {
          deviceId: string;
          status: DeviceStatus;
          metadata?: Partial<Device>;
        };
        get().updateDevice(deviceId, { status, ...metadata });
        console.log('Device status updated:', deviceId, status);
        break;
      }

      default:
        break;
    }
  },
}));

// Initialize WebSocket listener
export function initializeDeviceWebSocket() {
  const ws = getWebSocketService();

  // Subscribe to device updates channel
  ws.subscribe('DevicesChannel');

  // Listen to all WebSocket messages
  const unsubscribe = ws.onMessage((message) => {
    useDeviceStore.getState().handleWebSocketMessage(message);
  });

  return unsubscribe;
}
