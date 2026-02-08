import { useEffect } from 'react';
import { useLayoutStore } from '../stores/layoutStore';

export function useKeyboardShortcuts() {
  const { toggleSidebar, toggleCommandPalette } = useLayoutStore();

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Cmd/Ctrl + K: Open command palette
      if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        toggleCommandPalette();
        return;
      }

      // Cmd/Ctrl + B: Toggle sidebar
      if (e.key === 'b' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        toggleSidebar();
        return;
      }

      // Cmd/Ctrl + /: Show shortcuts help (placeholder)
      if (e.key === '/' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        console.log('Keyboard shortcuts:', {
          'Cmd/Ctrl + K': 'Open command palette',
          'Cmd/Ctrl + B': 'Toggle sidebar',
          'Cmd/Ctrl + /': 'Show shortcuts help',
        });
        return;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [toggleSidebar, toggleCommandPalette]);
}
