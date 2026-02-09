import { useTheme } from '@/hooks';
import type { ThemeMode, ColorScheme } from '@/contexts/ThemeContext';
import { Button } from '@/components/ui/Button';

const THEME_MODES: { value: ThemeMode; label: string; icon: string }[] = [
  { value: 'light', label: 'Light', icon: '☀️' },
  { value: 'dark', label: 'Dark', icon: '🌙' },
  { value: 'auto', label: 'Auto', icon: '🔄' },
];

const COLOR_SCHEMES: { value: ColorScheme; label: string; color: string }[] = [
  { value: 'blue', label: 'Blue', color: '#3b82f6' },
  { value: 'purple', label: 'Purple', color: '#a855f7' },
  { value: 'green', label: 'Green', color: '#22c55e' },
  { value: 'red', label: 'Red', color: '#ef4444' },
];

export function ThemeSwitcher() {
  const { theme, setThemeMode, setColorScheme, setCustomAccent, resetTheme } = useTheme();

  return (
    <div className="space-y-6 p-4">
      {/* Theme Mode Selector */}
      <div>
        <h3 className="text-lg font-semibold theme-text mb-3">Theme Mode</h3>
        <div className="flex gap-2">
          {THEME_MODES.map(mode => (
            <button
              key={mode.value}
              onClick={() => setThemeMode(mode.value)}
              className={`
                flex-1 px-4 py-3 rounded-lg border-2 transition-all theme-transition
                flex flex-col items-center gap-2
                ${
                  theme.mode === mode.value
                    ? 'border-theme-primary bg-theme-primary/10 theme-primary'
                    : 'border-theme-border theme-text-muted hover:border-theme-primary/50'
                }
              `}
            >
              <span className="text-2xl">{mode.icon}</span>
              <span className="text-sm font-medium">{mode.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Color Scheme Selector */}
      <div>
        <h3 className="text-lg font-semibold theme-text mb-3">Color Scheme</h3>
        <div className="grid grid-cols-2 gap-3">
          {COLOR_SCHEMES.map(scheme => (
            <button
              key={scheme.value}
              onClick={() => setColorScheme(scheme.value)}
              className={`
                px-4 py-3 rounded-lg border-2 transition-all theme-transition
                flex items-center gap-3
                ${
                  theme.colorScheme === scheme.value
                    ? 'border-theme-primary bg-theme-primary/10'
                    : 'border-theme-border hover:border-theme-primary/50'
                }
              `}
            >
              <div
                className="w-6 h-6 rounded-full"
                style={{ backgroundColor: scheme.color }}
              />
              <span className="text-sm font-medium theme-text">{scheme.label}</span>
              {theme.colorScheme === scheme.value && (
                <span className="ml-auto theme-primary">✓</span>
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Custom Accent Color */}
      <div>
        <h3 className="text-lg font-semibold theme-text mb-3">Custom Accent</h3>
        <div className="flex gap-2">
          <input
            type="color"
            value={theme.customAccent || '#3b82f6'}
            onChange={(e) => setCustomAccent(e.target.value)}
            className="h-12 w-20 rounded-lg cursor-pointer border-2 border-theme-border"
          />
          <input
            type="text"
            value={theme.customAccent || ''}
            onChange={(e) => setCustomAccent(e.target.value)}
            placeholder="Custom color (e.g., #3b82f6)"
            className="flex-1 px-4 py-2 rounded-lg border-2 border-theme-border theme-bg-elevated theme-text"
          />
        </div>
      </div>

      {/* Preview Section */}
      <div className="theme-bg-card border-2 border-theme-border rounded-lg p-4">
        <h3 className="text-lg font-semibold theme-text mb-3">Preview</h3>
        <div className="space-y-3">
          <Button variant="primary" className="w-full">
            Primary Button
          </Button>
          <Button variant="secondary" className="w-full">
            Secondary Button
          </Button>
          <div className="p-3 rounded-lg theme-bg-elevated">
            <p className="theme-text">This is theme text</p>
            <p className="theme-text-muted text-sm">This is muted text</p>
          </div>
        </div>
      </div>

      {/* Reset Button */}
      <Button variant="secondary" onClick={resetTheme} className="w-full">
        Reset to Defaults
      </Button>
    </div>
  );
}
