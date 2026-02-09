import { create } from 'zustand';
import type { Device } from '@/types/index';

interface AppState {
  devices: Device[];
  selectedDevice: Device | null;
  isLoading: boolean;
  error: string | null;
  setDevices: (devices: Device[]) => void;
  setSelectedDevice: (device: Device | null) => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
}

export const useAppStore = create<AppState>((set) => ({
  devices: [],
  selectedDevice: null,
  isLoading: false,
  error: null,
  setDevices: (devices) => set({ devices }),
  setSelectedDevice: (device) => set({ selectedDevice: device }),
  setLoading: (loading) => set({ isLoading: loading }),
  setError: (error) => set({ error }),
}));
