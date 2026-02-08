import { useEffect, useCallback } from 'react';
import { useDeviceStore } from '../stores/deviceStore';
import type { Device } from '../types/api';
import { DeviceStatus } from '../types/api';
import { initializeDeviceWebSocket } from '../stores/deviceStore';

export function useDevices() {
  const devices = useDeviceStore((state) => state.getDevicesList());
  const loading = useDeviceStore((state) => state.loading);
  const error = useDeviceStore((state) => state.error);
  const fetchDevices = useDeviceStore((state) => state.fetchDevices);
  const clearError = useDeviceStore((state) => state.clearError);

  useEffect(() => {
    // Initialize WebSocket connection for devices
    const unsubscribe = initializeDeviceWebSocket();

    // Fetch initial devices
    fetchDevices();

    return () => {
      unsubscribe();
    };
  }, [fetchDevices]);

  const refresh = useCallback(() => {
    return fetchDevices();
  }, [fetchDevices]);

  return {
    devices,
    loading,
    error,
    refresh,
    clearError,
  };
}

export function useDevice(deviceId: string | null) {
  const device = useDeviceStore(
    useCallback((state) => (deviceId ? state.getDevice(deviceId) : null), [deviceId])
  );
  const loading = useDeviceStore((state) => state.loading);
  const error = useDeviceStore((state) => state.error);
  const fetchDevice = useDeviceStore((state) => state.fetchDevice);
  const updateDevice = useDeviceStore((state) => state.updateDevice);
  const clearError = useDeviceStore((state) => state.clearError);

  useEffect(() => {
    if (deviceId) {
      fetchDevice(deviceId);
    }
  }, [deviceId, fetchDevice]);

  const update = useCallback(
    (updates: Partial<Device>) => {
      if (deviceId) {
        updateDevice(deviceId, updates);
      }
    },
    [deviceId, updateDevice]
  );

  const refresh = useCallback(() => {
    if (deviceId) {
      return fetchDevice(deviceId);
    }
  }, [deviceId, fetchDevice]);

  return {
    device,
    loading,
    error,
    update,
    refresh,
    clearError,
  };
}

export function useSelectedDevice() {
  const selectedDeviceId = useDeviceStore((state) => state.selectedDeviceId);
  const selectedDevice = useDeviceStore((state) => state.getSelectedDevice());
  const selectDevice = useDeviceStore((state) => state.selectDevice);

  return {
    selectedDeviceId,
    selectedDevice,
    selectDevice,
  };
}

export function useDeviceStatus(deviceId: string | null) {
  const status = useDeviceStore(
    useCallback(
      (state) => {
        if (!deviceId) return null;
        const device = state.getDevice(deviceId);
        return device?.status || null;
      },
      [deviceId]
    )
  );

  const isOnline = status === DeviceStatus.ONLINE;
  const isOffline = status === DeviceStatus.OFFLINE;
  const isBusy = status === DeviceStatus.BUSY;

  return {
    status,
    isOnline,
    isOffline,
    isBusy,
  };
}

export function useOnlineDevices() {
  const onlineDevices = useDeviceStore((state) => state.getOnlineDevices());

  return {
    onlineDevices,
    count: onlineDevices.length,
  };
}
