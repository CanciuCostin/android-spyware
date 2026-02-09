import { useState } from 'react';
import { useTheme } from '@/hooks';
import { ThemeSwitcher } from '@/components/settings/ThemeSwitcher';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';

export function ThemeSettings() {
  const { exportTheme, importTheme } = useTheme();
  const [importText, setImportText] = useState('');
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const handleExport = () => {
    const config = exportTheme();
    navigator.clipboard.writeText(config);
    setMessage({ type: 'success', text: 'Theme configuration copied to clipboard!' });
    setTimeout(() => setMessage(null), 3000);
  };

  const handleImport = () => {
    if (!importText.trim()) {
      setMessage({ type: 'error', text: 'Please paste a theme configuration' });
      setTimeout(() => setMessage(null), 3000);
      return;
    }

    const success = importTheme(importText);
    if (success) {
      setMessage({ type: 'success', text: 'Theme imported successfully!' });
      setImportText('');
    } else {
      setMessage({ type: 'error', text: 'Invalid theme configuration' });
    }
    setTimeout(() => setMessage(null), 3000);
  };

  const handleDownloadConfig = () => {
    const config = exportTheme();
    const blob = new Blob([config], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'eaglespy-theme.json';
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="min-h-screen theme-bg-base p-6">
      <div className="max-w-4xl mx-auto space-y-6">
        <div>
          <h1 className="text-3xl font-bold theme-text">Theme Settings</h1>
          <p className="theme-text-muted mt-2">
            Customize the appearance of your EagleSpy interface
          </p>
        </div>

        {message && (
          <div className="p-4 rounded-lg border-2 animate-fade-in">
            {message.text}
          </div>
        )}

        <Card className="theme-bg-card border-2 border-theme-border">
          <ThemeSwitcher />
        </Card>

        <Card className="theme-bg-card border-2 border-theme-border p-6">
          <h2 className="text-xl font-semibold theme-text mb-4">Import/Export Theme</h2>
          <div className="space-y-4">
            <div>
              <h3 className="text-sm font-medium theme-text mb-2">Export Configuration</h3>
              <div className="flex gap-2">
                <Button variant="secondary" onClick={handleExport} className="flex-1">
                  Copy to Clipboard
                </Button>
                <Button variant="secondary" onClick={handleDownloadConfig} className="flex-1">
                  Download JSON
                </Button>
              </div>
            </div>
            <div>
              <h3 className="text-sm font-medium theme-text mb-2">Import Configuration</h3>
              <textarea
                value={importText}
                onChange={(e) => setImportText(e.target.value)}
                placeholder="Paste theme configuration JSON here..."
                className="w-full px-4 py-3 rounded-lg border-2 border-theme-border theme-bg-elevated theme-text font-mono text-sm resize-y min-h-32"
              />
              <Button variant="primary" onClick={handleImport} disabled={!importText.trim()} className="w-full mt-2">
                Import Theme
              </Button>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
