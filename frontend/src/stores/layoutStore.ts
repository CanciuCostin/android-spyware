import { create } from 'zustand';

interface Tab {
  id: string;
  label: string;
  icon?: React.ReactNode;
}

interface BreadcrumbItem {
  label: string;
  path?: string;
}

interface LayoutStore {
  sidebarCollapsed: boolean;
  commandPaletteOpen: boolean;
  isMobile: boolean;
  activeTabs: Tab[];
  activeTabId: string | null;
  breadcrumbs: BreadcrumbItem[];

  // Sidebar actions
  toggleSidebar: () => void;
  setSidebarCollapsed: (collapsed: boolean) => void;
  closeMobileSidebar: () => void;

  // Command palette actions
  openCommandPalette: () => void;
  closeCommandPalette: () => void;
  toggleCommandPalette: () => void;

  // Tab actions
  addTab: (tab: Tab) => void;
  removeTab: (tabId: string) => void;
  setActiveTab: (tabId: string) => void;
  clearTabs: () => void;

  // Breadcrumb actions
  setBreadcrumbs: (breadcrumbs: BreadcrumbItem[]) => void;

  // Mobile detection
  setIsMobile: (isMobile: boolean) => void;
}

export const useLayoutStore = create<LayoutStore>((set, get) => ({
  sidebarCollapsed: false,
  commandPaletteOpen: false,
  isMobile: false,
  activeTabs: [],
  activeTabId: null,
  breadcrumbs: [],

  // Sidebar actions
  toggleSidebar: () => {
    set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed }));
  },

  setSidebarCollapsed: (collapsed: boolean) => {
    set({ sidebarCollapsed: collapsed });
  },

  closeMobileSidebar: () => {
    const { isMobile } = get();
    if (isMobile) {
      set({ sidebarCollapsed: true });
    }
  },

  // Command palette actions
  openCommandPalette: () => {
    set({ commandPaletteOpen: true });
  },

  closeCommandPalette: () => {
    set({ commandPaletteOpen: false });
  },

  toggleCommandPalette: () => {
    set((state) => ({ commandPaletteOpen: !state.commandPaletteOpen }));
  },

  // Tab actions
  addTab: (tab: Tab) => {
    set((state) => {
      const exists = state.activeTabs.some((t) => t.id === tab.id);
      if (exists) {
        return { activeTabId: tab.id };
      }
      return {
        activeTabs: [...state.activeTabs, tab],
        activeTabId: tab.id,
      };
    });
  },

  removeTab: (tabId: string) => {
    set((state) => {
      const newTabs = state.activeTabs.filter((tab) => tab.id !== tabId);
      let newActiveTabId = state.activeTabId;

      if (state.activeTabId === tabId && newTabs.length > 0) {
        const removedIndex = state.activeTabs.findIndex((tab) => tab.id === tabId);
        const newIndex = Math.max(0, removedIndex - 1);
        newActiveTabId = newTabs[newIndex]?.id || newTabs[0]?.id || null;
      }

      return {
        activeTabs: newTabs,
        activeTabId: newActiveTabId,
      };
    });
  },

  setActiveTab: (tabId: string) => {
    set({ activeTabId: tabId });
  },

  clearTabs: () => {
    set({ activeTabs: [], activeTabId: null });
  },

  // Breadcrumb actions
  setBreadcrumbs: (breadcrumbs: BreadcrumbItem[]) => {
    set({ breadcrumbs });
  },

  // Mobile detection
  setIsMobile: (isMobile: boolean) => {
    set({ isMobile });
  },
}));
