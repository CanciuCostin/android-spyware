import axios, { type AxiosInstance, AxiosError, type InternalAxiosRequestConfig } from 'axios';
import type {
  ApiResponse,
  Device,
  Command,
  SendCommandRequest,
  DeviceQuery,
  CommandQuery,
} from '../types/api';

class ApiService {
  private client: AxiosInstance;
  private authToken: string | null = null;

  constructor() {
    const baseURL = import.meta.env.VITE_API_URL || 'http://localhost:3000/api';

    this.client = axios.create({
      baseURL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
      withCredentials: true,
    });

    this.setupInterceptors();
  }

  private setupInterceptors(): void {
    // Request interceptor
    this.client.interceptors.request.use(
      (config: InternalAxiosRequestConfig) => {
        if (this.authToken) {
          config.headers.Authorization = `Bearer ${this.authToken}`;
        }

        // Add CSRF token if available
        const csrfToken = this.getCsrfToken();
        if (csrfToken) {
          config.headers['X-CSRF-Token'] = csrfToken;
        }

        console.log(`API Request: ${config.method?.toUpperCase()} ${config.url}`);
        return config;
      },
      (error: AxiosError) => {
        console.error('Request error:', error);
        return Promise.reject(error);
      }
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => {
        console.log(`API Response: ${response.status} ${response.config.url}`);
        return response;
      },
      async (error: AxiosError) => {
        console.error('Response error:', error);

        if (error.response) {
          const { status } = error.response;

          if (status === 401) {
            // Unauthorized - clear auth and redirect to login
            this.clearAuth();
            window.location.href = '/login';
          } else if (status === 403) {
            console.error('Forbidden: insufficient permissions');
          } else if (status === 404) {
            console.error('Resource not found');
          } else if (status >= 500) {
            console.error('Server error');
          }
        } else if (error.request) {
          console.error('No response received from server');
        }

        return Promise.reject(this.formatError(error));
      }
    );
  }

  private formatError(error: AxiosError): { message: string; status?: number; data?: unknown } {
    if (error.response) {
      return {
        message: (error.response.data as { error?: string })?.error || error.message,
        status: error.response.status,
        data: error.response.data,
      };
    } else if (error.request) {
      return {
        message: 'No response from server. Please check your connection.',
      };
    }
    return {
      message: error.message || 'An unexpected error occurred',
    };
  }

  private getCsrfToken(): string | null {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta?.getAttribute('content') || null;
  }

  // Auth methods
  setAuthToken(token: string): void {
    this.authToken = token;
    localStorage.setItem('auth_token', token);
  }

  clearAuth(): void {
    this.authToken = null;
    localStorage.removeItem('auth_token');
  }

  loadAuthToken(): void {
    const token = localStorage.getItem('auth_token');
    if (token) {
      this.authToken = token;
    }
  }

  // Device endpoints
  async getDevices(query?: DeviceQuery): Promise<ApiResponse<Device[]>> {
    const response = await this.client.get<ApiResponse<Device[]>>('/devices', { params: query });
    return response.data;
  }

  async getDevice(id: string): Promise<ApiResponse<Device>> {
    const response = await this.client.get<ApiResponse<Device>>(`/devices/${id}`);
    return response.data;
  }

  async updateDevice(id: string, data: Partial<Device>): Promise<ApiResponse<Device>> {
    const response = await this.client.patch<ApiResponse<Device>>(`/devices/${id}`, data);
    return response.data;
  }

  async deleteDevice(id: string): Promise<ApiResponse<void>> {
    const response = await this.client.delete<ApiResponse<void>>(`/devices/${id}`);
    return response.data;
  }

  // Command endpoints
  async getCommands(query?: CommandQuery): Promise<ApiResponse<Command[]>> {
    const response = await this.client.get<ApiResponse<Command[]>>('/commands', { params: query });
    return response.data;
  }

  async getCommand(id: string): Promise<ApiResponse<Command>> {
    const response = await this.client.get<ApiResponse<Command>>(`/commands/${id}`);
    return response.data;
  }

  async sendCommand(request: SendCommandRequest): Promise<ApiResponse<Command>> {
    const response = await this.client.post<ApiResponse<Command>>('/commands', request);
    return response.data;
  }

  async cancelCommand(id: string): Promise<ApiResponse<Command>> {
    const response = await this.client.post<ApiResponse<Command>>(`/commands/${id}/cancel`);
    return response.data;
  }

  // Health check
  async healthCheck(): Promise<{ status: string; timestamp: string }> {
    const response = await this.client.get<{ status: string; timestamp: string }>('/health');
    return response.data;
  }

  // Generic methods for backward compatibility
  async get<T>(url: string): Promise<T> {
    const response = await this.client.get<T>(url);
    return response.data;
  }

  async post<T>(url: string, data?: unknown): Promise<T> {
    const response = await this.client.post<T>(url, data);
    return response.data;
  }

  async put<T>(url: string, data?: unknown): Promise<T> {
    const response = await this.client.put<T>(url, data);
    return response.data;
  }

  async delete<T>(url: string): Promise<T> {
    const response = await this.client.delete<T>(url);
    return response.data;
  }
}

// Singleton instance
let instance: ApiService | null = null;

export function getApiService(): ApiService {
  if (!instance) {
    instance = new ApiService();
    instance.loadAuthToken();
  }
  return instance;
}

export function resetApiService(): void {
  instance = null;
}

// Export singleton for backward compatibility
export const apiService = getApiService();
