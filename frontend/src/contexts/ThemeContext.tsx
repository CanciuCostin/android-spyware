import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';

export type ThemeMode = 'light' | 'dark' | 'auto';
export type ColorScheme = 'blue' | 'purple' | 'green' | 'red';

export interface ThemeConfig {
  mode: ThemeMode;
  colorScheme: ColorScheme;
  customAccent?: string;
}

interface ThemeContextType {
  theme: ThemeConfig;
  effectiveTheme: 'light' | 'dark';
  setThemeMode: (mode: ThemeMode) => void;
  setColorScheme: (scheme: ColorScheme) => void;
  setCustomAccent: (color: string) => void;
  resetTheme: () => void;
  exportTheme: () => string;
  importTheme: (config: string) => boolean;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

const STORAGE_KEY = 'eaglespy-theme';
const DEFAULT_THEME: ThemeConfig = {
  mode: 'auto',
  colorScheme: 'blue',
};

const COLOR_SCHEMES = {
  blue: {
    primary: '59 130 246', // #3b82f6
    secondary: '37 99 235', // #2563eb
    accent: '147 197 253', // #93c5fd
  },
  purple: {
    primary: '168 85 247', // #a855f7
    secondary: '147 51 234', // #9333ea
    accent: '216 180 254', // #d8b4fe
  },
  green: {
    primary: '34 197 94', // #22c55e
    secondary: '22 163 74', // #16a34a
    accent: '134 239 172', // #86efac
  },
  red: {
    primary: '239 68 68', // #ef4444
    secondary: '220 38 38', // #dc2626
    accent: '252 165 165', // #fca5a5
  },
};

function getSystemTheme(): 'light' | 'dark' {
  if (typeof window === 'undefined') return 'dark';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function loadTheme(): ThemeConfig {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      const parsed = JSON.parse(stored);
      return { ...DEFAULT_THEME, ...parsed };
    }
  } catch (error) {
    console.error('Failed to load theme:', error);
  }
  return DEFAULT_THEME;
}

function saveTheme(theme: ThemeConfig): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(theme));
  } catch (error) {
    console.error('Failed to save theme:', error);
  }
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<ThemeConfig>(loadTheme);
  const [systemTheme, setSystemTheme] = useState<'light' | 'dark'>(getSystemTheme);

  // Listen for system theme changes
  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = (e: MediaQueryListEvent) => {
      setSystemTheme(e.matches ? 'dark' : 'light');
    };

    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  // Calculate effective theme
  const effectiveTheme = theme.mode === 'auto' ? systemTheme : theme.mode;

  // Apply theme to document
  useEffect(() => {
    const root = document.documentElement;

    // Apply theme mode
    root.classList.remove('light', 'dark');
    root.classList.add(effectiveTheme);
    root.setAttribute('data-theme', effectiveTheme);

    // Apply color scheme
    root.setAttribute('data-color-scheme', theme.colorScheme);

    // Apply color variables
    const colors = COLOR_SCHEMES[theme.colorScheme];
    root.style.setProperty('--color-primary', colors.primary);
    root.style.setProperty('--color-secondary', colors.secondary);
    root.style.setProperty('--color-accent', colors.accent);

    // Apply custom accent if set
    if (theme.customAccent) {
      root.style.setProperty('--color-custom-accent', theme.customAccent);
    }

    // Save theme
    saveTheme(theme);
  }, [theme, effectiveTheme]);

  const setThemeMode = (mode: ThemeMode) => {
    setTheme(prev => ({ ...prev, mode }));
  };

  const setColorScheme = (colorScheme: ColorScheme) => {
    setTheme(prev => ({ ...prev, colorScheme }));
  };

  const setCustomAccent = (customAccent: string) => {
    setTheme(prev => ({ ...prev, customAccent }));
  };

  const resetTheme = () => {
    setTheme(DEFAULT_THEME);
  };

  const exportTheme = (): string => {
    return JSON.stringify(theme, null, 2);
  };

  const importTheme = (config: string): boolean => {
    try {
      const parsed = JSON.parse(config);
      if (parsed.mode && parsed.colorScheme) {
        setTheme(parsed);
        return true;
      }
      return false;
    } catch {
      return false;
    }
  };

  const value: ThemeContextType = {
    theme,
    effectiveTheme,
    setThemeMode,
    setColorScheme,
    setCustomAccent,
    resetTheme,
    exportTheme,
    importTheme,
  };

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useThemeContext() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useThemeContext must be used within ThemeProvider');
  }
  return context;
}
