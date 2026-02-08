export interface Device {
  id: string;
  name: string;
  status: 'online' | 'offline';
  lastSeen: string;
}

export interface ApiResponse<T> {
  data: T;
  success: boolean;
  message?: string;
}
