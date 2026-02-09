import type { ReactNode } from 'react';
import { useEffect } from 'react';
import { Sidebar } from './Sidebar';
import { TopNav } from './TopNav';
import { CommandPalette } from './CommandPalette';
import { useLayoutStore } from '../../stores/layoutStore';
import { useKeyboardShortcuts } from '../../hooks/useKeyboardShortcuts';

interface MainLayoutProps {
  children: ReactNode;
}

export function MainLayout({ children }: MainLayoutProps) {
  const { sidebarCollapsed, setIsMobile } = useLayoutStore();
  useKeyboardShortcuts();

  useEffect(() => {
    const checkMobile = () => {
      const mobile = window.innerWidth < 1024;
      setIsMobile(mobile);
      
      // Auto-collapse sidebar on mobile
      if (mobile && !sidebarCollapsed) {
        useLayoutStore.getState().closeMobileSidebar();
      }
    };

    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, [sidebarCollapsed, setIsMobile]);

  return (
    <div className="flex h-screen overflow-hidden bg-gray-50">
      <Sidebar />

      <div className="flex-1 flex flex-col overflow-hidden">
        <TopNav />

        <main className="flex-1 overflow-y-auto">
          <div className="container mx-auto px-4 lg:px-6 py-6">
            {children}
          </div>
        </main>
      </div>

      <CommandPalette />
    </div>
  );
}
