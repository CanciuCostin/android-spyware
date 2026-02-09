import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { Layout } from 'react-grid-layout';

interface SplitScreenConfig {
  enabled: boolean;
  orientation: 'horizontal' | 'vertical';
  sizes: [number, number];
  device1Id?: string;
  device2Id?: string;
  syncScroll: boolean;
}

interface PiPPanelState {
  id: string;
  title: string;
  position: { x: number; y: number };
  size: { width: number; height: number };
  isMinimized: boolean;
  isMaximized: boolean;
  contentType: 'camera' | 'terminal' | 'custom';
  deviceId?: string;
}

interface WidgetLayout {
  id: string;
  layout: Layout[];
  activeWidgets: string[];
}

interface AdvancedStore {
  // Split Screen
  splitScreen: SplitScreenConfig;
  setSplitScreen: (config: Partial<SplitScreenConfig>) => void;
  toggleSplitScreen: () => void;
  swapSplitDevices: () => void;

  // PiP Panels
  pipPanels: PiPPanelState[];
  addPiPPanel: (panel: Omit<PiPPanelState, 'id'>) => string;
  removePiPPanel: (id: string) => void;
  updatePiPPanel: (id: string, updates: Partial<PiPPanelState>) => void;
  clearPiPPanels: () => void;

  // Widget Grid
  widgetLayouts: Record<string, WidgetLayout>;
  saveWidgetLayout: (dashboardId: string, layout: Layout[], activeWidgets: string[]) => void;
  loadWidgetLayout: (dashboardId: string) => WidgetLayout | null;

  // Panel Sizes
  panelSizes: Record<string, number[]>;
  savePanelSizes: (panelGroupId: string, sizes: number[]) => void;
  loadPanelSizes: (panelGroupId: string) => number[] | null;

  // Keyboard Shortcuts
  shortcutsPanelOpen: boolean;
  toggleShortcutsPanel: () => void;

  // Context Menu
  contextMenuOpen: boolean;
  contextMenuPosition: { x: number; y: number };
  contextMenuItems: any[];
  openContextMenu: (x: number, y: number, items: any[]) => void;
  closeContextMenu: () => void;

  // Reset
  resetAdvancedSettings: () => void;
}

const defaultState = {
  splitScreen: {
    enabled: false,
    orientation: 'vertical' as const,
    sizes: [50, 50] as [number, number],
    device1Id: undefined,
    device2Id: undefined,
    syncScroll: false,
  },
  pipPanels: [],
  widgetLayouts: {},
  panelSizes: {},
  shortcutsPanelOpen: false,
  contextMenuOpen: false,
  contextMenuPosition: { x: 0, y: 0 },
  contextMenuItems: [],
};

export const useAdvancedStore = create<AdvancedStore>()(
  persist(
    (set, get) => ({
      ...defaultState,

      // Split Screen Actions
      setSplitScreen: (config) =>
        set((state) => ({
          splitScreen: { ...state.splitScreen, ...config },
        })),

      toggleSplitScreen: () =>
        set((state) => ({
          splitScreen: {
            ...state.splitScreen,
            enabled: !state.splitScreen.enabled,
          },
        })),

      swapSplitDevices: () =>
        set((state) => ({
          splitScreen: {
            ...state.splitScreen,
            device1Id: state.splitScreen.device2Id,
            device2Id: state.splitScreen.device1Id,
          },
        })),

      // PiP Panel Actions
      addPiPPanel: (panel) => {
        const id = `pip-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        const newPanel = { ...panel, id };
        set((state) => ({
          pipPanels: [...state.pipPanels, newPanel],
        }));
        return id;
      },

      removePiPPanel: (id) =>
        set((state) => ({
          pipPanels: state.pipPanels.filter((panel) => panel.id !== id),
        })),

      updatePiPPanel: (id, updates) =>
        set((state) => ({
          pipPanels: state.pipPanels.map((panel) =>
            panel.id === id ? { ...panel, ...updates } : panel
          ),
        })),

      clearPiPPanels: () => set({ pipPanels: [] }),

      // Widget Grid Actions
      saveWidgetLayout: (dashboardId, layout, activeWidgets) =>
        set((state) => ({
          widgetLayouts: {
            ...state.widgetLayouts,
            [dashboardId]: { id: dashboardId, layout, activeWidgets },
          },
        })),

      loadWidgetLayout: (dashboardId) => {
        return get().widgetLayouts[dashboardId] || null;
      },

      // Panel Sizes Actions
      savePanelSizes: (panelGroupId, sizes) =>
        set((state) => ({
          panelSizes: {
            ...state.panelSizes,
            [panelGroupId]: sizes,
          },
        })),

      loadPanelSizes: (panelGroupId) => {
        return get().panelSizes[panelGroupId] || null;
      },

      // Keyboard Shortcuts Actions
      toggleShortcutsPanel: () =>
        set((state) => ({
          shortcutsPanelOpen: !state.shortcutsPanelOpen,
        })),

      // Context Menu Actions
      openContextMenu: (x, y, items) =>
        set({
          contextMenuOpen: true,
          contextMenuPosition: { x, y },
          contextMenuItems: items,
        }),

      closeContextMenu: () =>
        set({
          contextMenuOpen: false,
          contextMenuItems: [],
        }),

      // Reset
      resetAdvancedSettings: () => set(defaultState),
    }),
    {
      name: 'eaglespy-advanced-store',
      partialize: (state) => ({
        splitScreen: state.splitScreen,
        widgetLayouts: state.widgetLayouts,
        panelSizes: state.panelSizes,
      }),
    }
  )
);
