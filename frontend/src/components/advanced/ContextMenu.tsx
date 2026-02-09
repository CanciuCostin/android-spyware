import { useState, useRef, useEffect, useCallback } from 'react';
import { ChevronRight } from 'lucide-react';

export interface MenuItem {
  id: string;
  label: string;
  icon?: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  divider?: boolean;
  submenu?: MenuItem[];
}

interface ContextMenuProps {
  items: MenuItem[];
  trigger: React.ReactNode;
}

export const ContextMenu: React.FC<ContextMenuProps> = ({ items, trigger }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [activeSubmenu, setActiveSubmenu] = useState<string | null>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLDivElement>(null);

  const handleContextMenu = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();

    // Calculate position
    const x = e.clientX;
    const y = e.clientY;

    // Adjust if menu would go off screen
    const menuWidth = 200;
    const menuHeight = items.length * 40;
    
    const adjustedX = x + menuWidth > window.innerWidth ? window.innerWidth - menuWidth - 10 : x;
    const adjustedY = y + menuHeight > window.innerHeight ? window.innerHeight - menuHeight - 10 : y;

    setPosition({ x: adjustedX, y: adjustedY });
    setIsOpen(true);
  }, [items.length]);

  const handleClose = useCallback(() => {
    setIsOpen(false);
    setActiveSubmenu(null);
  }, []);

  const handleItemClick = useCallback((item: MenuItem) => {
    if (item.disabled) return;
    
    if (item.submenu) {
      setActiveSubmenu(activeSubmenu === item.id ? null : item.id);
    } else {
      item.onClick?.();
      handleClose();
    }
  }, [activeSubmenu, handleClose]);

  // Handle clicks outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        handleClose();
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
  }, [isOpen, handleClose]);

  // Handle Escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        handleClose();
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      return () => document.removeEventListener('keydown', handleEscape);
    }
  }, [isOpen, handleClose]);

  // Handle keyboard navigation
  useEffect(() => {
    const handleKeyNav = (e: KeyboardEvent) => {
      if (!isOpen) return;

      const enabledItems = items.filter((item) => !item.disabled && !item.divider);
      const currentIndex = enabledItems.findIndex((item) => item.id === activeSubmenu);

      if (e.key === 'ArrowDown') {
        e.preventDefault();
        const nextIndex = (currentIndex + 1) % enabledItems.length;
        setActiveSubmenu(enabledItems[nextIndex].id);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        const prevIndex = (currentIndex - 1 + enabledItems.length) % enabledItems.length;
        setActiveSubmenu(enabledItems[prevIndex].id);
      } else if (e.key === 'Enter' && activeSubmenu) {
        e.preventDefault();
        const item = items.find((i) => i.id === activeSubmenu);
        if (item) handleItemClick(item);
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleKeyNav);
      return () => document.removeEventListener('keydown', handleKeyNav);
    }
  }, [isOpen, items, activeSubmenu, handleItemClick]);

  const renderMenuItem = (item: MenuItem, isSubmenu = false) => {
    if (item.divider) {
      return <div key={item.id} className="h-px bg-gray-700 my-1" />;
    }

    return (
      <div
        key={item.id}
        className={`
          relative px-3 py-2 flex items-center gap-2 cursor-pointer
          ${item.disabled ? 'opacity-50 cursor-not-allowed' : 'hover:bg-gray-700'}
          ${activeSubmenu === item.id ? 'bg-gray-700' : ''}
        `}
        onClick={() => handleItemClick(item)}
        onMouseEnter={() => item.submenu && setActiveSubmenu(item.id)}
      >
        {item.icon && <span className="text-gray-400">{item.icon}</span>}
        <span className="text-white text-sm flex-1">{item.label}</span>
        {item.submenu && <ChevronRight size={14} className="text-gray-400" />}

        {/* Submenu */}
        {item.submenu && activeSubmenu === item.id && (
          <div
            className="absolute left-full top-0 ml-1 bg-gray-800 border border-gray-700 rounded-lg shadow-xl py-1 min-w-[180px] z-50"
          >
            {item.submenu.map((subItem) => renderMenuItem(subItem, true))}
          </div>
        )}
      </div>
    );
  };

  return (
    <>
      <div
        ref={triggerRef}
        onContextMenu={handleContextMenu}
        className="inline-block"
      >
        {trigger}
      </div>

      {isOpen && (
        <div
          ref={menuRef}
          className="fixed bg-gray-800 border border-gray-700 rounded-lg shadow-2xl py-1 min-w-[200px] z-[10000]"
          style={{
            left: `${position.x}px`,
            top: `${position.y}px`,
          }}
        >
          {items.map((item) => renderMenuItem(item))}
        </div>
      )}
    </>
  );
};
