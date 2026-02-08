import { create } from 'zustand';

interface DeviceGroup {
  id: number;
  name: string;
  description: string;
  color: string;
  online_count: number;
  total_count: number;
  battery_average: number;
  last_activity: string;
  devices: any[];
}

interface BulkOperation {
  id: string;
  groupId: number;
  commandType: string;
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  totalDevices: number;
  successCount: number;
  failedCount: number;
  createdAt: Date;
}

interface FleetStore {
  groups: DeviceGroup[];
  selectedGroup: DeviceGroup | null;
  bulkOperations: BulkOperation[];
  loading: boolean;
  error: string | null;

  fetchGroups: () => Promise<void>;
  fetchGroupDetails: (id: number) => Promise<void>;
  createGroup: (data: Partial<DeviceGroup>) => Promise<void>;
  updateGroup: (id: number, data: Partial<DeviceGroup>) => Promise<void>;
  deleteGroup: (id: number) => Promise<void>;
  addDevicesToGroup: (groupId: number, deviceIds: number[]) => Promise<void>;
  removeDevicesFromGroup: (groupId: number, deviceIds: number[]) => Promise<void>;
  executeBulkCommand: (groupId: number, commandType: string, params: any) => Promise<void>;
  setSelectedGroup: (group: DeviceGroup | null) => void;
}

export const useFleetStore = create<FleetStore>((set, get) => ({
  groups: [],
  selectedGroup: null,
  bulkOperations: [],
  loading: false,
  error: null,

  fetchGroups: async () => {
    set({ loading: true, error: null });
    try {
      const response = await fetch('/device_groups');
      const data = await response.json();
      set({ groups: data, loading: false });
    } catch (error) {
      set({ error: 'Failed to fetch groups', loading: false });
    }
  },

  fetchGroupDetails: async (id: number) => {
    set({ loading: true, error: null });
    try {
      const response = await fetch(`/device_groups/${id}`);
      const data = await response.json();
      set({ selectedGroup: data, loading: false });
    } catch (error) {
      set({ error: 'Failed to fetch group details', loading: false });
    }
  },

  createGroup: async (data: Partial<DeviceGroup>) => {
    set({ loading: true, error: null });
    try {
      const response = await fetch('/device_groups', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_group: data }),
      });

      if (!response.ok) throw new Error('Failed to create group');

      await get().fetchGroups();
    } catch (error) {
      set({ error: 'Failed to create group', loading: false });
      throw error;
    }
  },

  updateGroup: async (id: number, data: Partial<DeviceGroup>) => {
    set({ loading: true, error: null });
    try {
      const response = await fetch(`/device_groups/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_group: data }),
      });

      if (!response.ok) throw new Error('Failed to update group');

      await get().fetchGroups();
    } catch (error) {
      set({ error: 'Failed to update group', loading: false });
      throw error;
    }
  },

  deleteGroup: async (id: number) => {
    set({ loading: true, error: null });
    try {
      const response = await fetch(`/device_groups/${id}`, {
        method: 'DELETE',
      });

      if (!response.ok) throw new Error('Failed to delete group');

      set((state) => ({
        groups: state.groups.filter((g) => g.id !== id),
        loading: false,
      }));
    } catch (error) {
      set({ error: 'Failed to delete group', loading: false });
      throw error;
    }
  },

  addDevicesToGroup: async (groupId: number, deviceIds: number[]) => {
    try {
      const response = await fetch(`/device_groups/${groupId}/add_devices`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_ids: deviceIds }),
      });

      if (!response.ok) throw new Error('Failed to add devices');

      await get().fetchGroupDetails(groupId);
    } catch (error) {
      set({ error: 'Failed to add devices to group' });
      throw error;
    }
  },

  removeDevicesFromGroup: async (groupId: number, deviceIds: number[]) => {
    try {
      const response = await fetch(`/device_groups/${groupId}/remove_devices`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_ids: deviceIds }),
      });

      if (!response.ok) throw new Error('Failed to remove devices');

      await get().fetchGroupDetails(groupId);
    } catch (error) {
      set({ error: 'Failed to remove devices from group' });
      throw error;
    }
  },

  executeBulkCommand: async (groupId: number, commandType: string, params: any) => {
    try {
      const response = await fetch(`/device_groups/${groupId}/bulk_command`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          command_type: commandType,
          command_params: params,
        }),
      });

      if (!response.ok) throw new Error('Failed to execute bulk command');

      const result = await response.json();

      const operation: BulkOperation = {
        id: `${groupId}-${Date.now()}`,
        groupId,
        commandType,
        status: 'completed',
        totalDevices: result.sent,
        successCount: result.sent,
        failedCount: 0,
        createdAt: new Date(),
      };

      set((state) => ({
        bulkOperations: [...state.bulkOperations, operation],
      }));

      return result;
    } catch (error) {
      set({ error: 'Failed to execute bulk command' });
      throw error;
    }
  },

  setSelectedGroup: (group: DeviceGroup | null) => {
    set({ selectedGroup: group });
  },
}));
