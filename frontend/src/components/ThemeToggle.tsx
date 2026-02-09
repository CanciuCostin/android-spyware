import { useTheme } from '@/hooks';

export function ThemeToggle() {
  const { effectiveTheme, setThemeMode, theme } = useTheme();

  const handleToggle = () => {
    if (theme.mode === 'auto') {
      setThemeMode(effectiveTheme === 'dark' ? 'light' : 'dark');
    } else {
      setThemeMode(theme.mode === 'dark' ? 'light' : 'dark');
    }
  };

  return (
    <button
      onClick={handleToggle}
      className="p-2 rounded-lg border-2 border-theme-border hover:bg-theme-primary/10 transition-all theme-transition"
      title={`Current theme: ${effectiveTheme}`}
    >
      {effectiveTheme === 'dark' ? '🌙' : '☀️'}
    </button>
  );
}
