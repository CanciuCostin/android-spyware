import { CSSProperties, ReactNode } from 'react';

interface VisuallyHiddenProps {
  children: ReactNode;
  as?: keyof JSX.IntrinsicElements;
}

const visuallyHiddenStyle: CSSProperties = {
  position: 'absolute',
  width: '1px',
  height: '1px',
  padding: '0',
  margin: '-1px',
  overflow: 'hidden',
  clip: 'rect(0, 0, 0, 0)',
  whiteSpace: 'nowrap',
  borderWidth: '0',
};

export function VisuallyHidden({ 
  children, 
  as: Component = 'span' 
}: VisuallyHiddenProps) {
  return (
    <Component style={visuallyHiddenStyle}>
      {children}
    </Component>
  );
}
