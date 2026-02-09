import { CSSProperties } from 'react';

interface SkipLinkProps {
  href?: string;
  label?: string;
}

const skipLinkStyle: CSSProperties = {
  position: 'absolute',
  left: '-9999px',
  zIndex: 9999,
  padding: '1rem',
  backgroundColor: 'var(--color-background)',
  color: 'var(--color-foreground)',
  textDecoration: 'none',
  border: '2px solid var(--color-primary)',
  borderRadius: '4px',
};

const skipLinkFocusStyle: CSSProperties = {
  ...skipLinkStyle,
  left: '1rem',
  top: '1rem',
};

export function SkipLink({ 
  href = '#main-content', 
  label = 'Skip to main content' 
}: SkipLinkProps) {
  return (
    <a
      href={href}
      style={skipLinkStyle}
      onFocus={(e) => {
        Object.assign(e.currentTarget.style, skipLinkFocusStyle);
      }}
      onBlur={(e) => {
        Object.assign(e.currentTarget.style, skipLinkStyle);
      }}
    >
      {label}
    </a>
  );
}
