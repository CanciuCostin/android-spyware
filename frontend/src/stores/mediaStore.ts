import { create } from 'zustand';

export interface MediaItem {
  id: string;
  type: 'photo' | 'video' | 'audio';
  url: string;
  thumbnailUrl?: string;
  filename: string;
  size: number;
  duration?: number;
  width?: number;
  height?: number;
  appSource?: string;
  capturedAt: string;
  deviceId: string;
  metadata?: Record<string, any>;
}

export interface MediaFilters {
  search: string;
  dateFrom?: Date;
  dateTo?: Date;
  appSource?: string;
  type?: 'photo' | 'video' | 'audio';
}

export interface MediaSort {
  field: 'date' | 'size' | 'name';
  order: 'asc' | 'desc';
}

interface MediaState {
  // Media items
  photos: MediaItem[];
  videos: MediaItem[];
  audios: MediaItem[];
  
  // Selection
  selectedItems: Set<string>;
  
  // Filters and sorting
  filters: MediaFilters;
  sort: MediaSort;
  
  // Lightbox
  lightboxOpen: boolean;
  lightboxIndex: number;
  lightboxItems: MediaItem[];
  
  // Pagination
  page: number;
  hasMore: boolean;
  loading: boolean;
  
  // Actions
  setPhotos: (photos: MediaItem[]) => void;
  setVideos: (videos: MediaItem[]) => void;
  setAudios: (audios: MediaItem[]) => void;
  addPhotos: (photos: MediaItem[]) => void;
  addVideos: (videos: MediaItem[]) => void;
  addAudios: (audios: MediaItem[]) => void;
  
  toggleSelection: (id: string) => void;
  selectAll: (items: MediaItem[]) => void;
  clearSelection: () => void;
  
  setFilters: (filters: Partial<MediaFilters>) => void;
  setSort: (sort: MediaSort) => void;
  
  openLightbox: (items: MediaItem[], index: number) => void;
  closeLightbox: () => void;
  setLightboxIndex: (index: number) => void;
  
  setPage: (page: number) => void;
  setHasMore: (hasMore: boolean) => void;
  setLoading: (loading: boolean) => void;
  
  deleteItems: (ids: string[]) => void;
}

export const useMediaStore = create<MediaState>((set) => ({
  // Initial state
  photos: [],
  videos: [],
  audios: [],
  selectedItems: new Set<string>(),
  filters: {
    search: '',
  },
  sort: {
    field: 'date',
    order: 'desc',
  },
  lightboxOpen: false,
  lightboxIndex: 0,
  lightboxItems: [],
  page: 1,
  hasMore: true,
  loading: false,
  
  // Actions
  setPhotos: (photos) => set({ photos }),
  setVideos: (videos) => set({ videos }),
  setAudios: (audios) => set({ audios }),
  
  addPhotos: (photos) => set((state) => ({
    photos: [...state.photos, ...photos],
  })),
  addVideos: (videos) => set((state) => ({
    videos: [...state.videos, ...videos],
  })),
  addAudios: (audios) => set((state) => ({
    audios: [...state.audios, ...audios],
  })),
  
  toggleSelection: (id) => set((state) => {
    const newSelection = new Set(state.selectedItems);
    if (newSelection.has(id)) {
      newSelection.delete(id);
    } else {
      newSelection.add(id);
    }
    return { selectedItems: newSelection };
  }),
  
  selectAll: (items) => set({
    selectedItems: new Set(items.map(item => item.id)),
  }),
  
  clearSelection: () => set({ selectedItems: new Set() }),
  
  setFilters: (filters) => set((state) => ({
    filters: { ...state.filters, ...filters },
    page: 1, // Reset page on filter change
  })),
  
  setSort: (sort) => set({ sort, page: 1 }),
  
  openLightbox: (items, index) => set({
    lightboxOpen: true,
    lightboxItems: items,
    lightboxIndex: index,
  }),
  
  closeLightbox: () => set({ lightboxOpen: false }),
  
  setLightboxIndex: (index) => set({ lightboxIndex: index }),
  
  setPage: (page) => set({ page }),
  setHasMore: (hasMore) => set({ hasMore }),
  setLoading: (loading) => set({ loading }),
  
  deleteItems: (ids) => set((state) => {
    const idSet = new Set(ids);
    return {
      photos: state.photos.filter(p => !idSet.has(p.id)),
      videos: state.videos.filter(v => !idSet.has(v.id)),
      audios: state.audios.filter(a => !idSet.has(a.id)),
      selectedItems: new Set([...state.selectedItems].filter(id => !idSet.has(id))),
    };
  }),
}));
