import React, { type HTMLAttributes } from 'react';

export type BadgeVariant = 'success' | 'warning' | 'danger' | 'info' | 'default';
export type BadgeSize = 'sm' | 'md' | 'lg';

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: BadgeVariant;
  size?: BadgeSize;
  dot?: boolean;
}

const variantStyles: Record<BadgeVariant, string> = {
  success: 'bg-neon-500/20 text-neon-400 border-neon-500/50',
  warning: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/50',
  danger: 'bg-red-500/20 text-red-400 border-red-500/50',
  info: 'bg-electric-500/20 text-electric-400 border-electric-500/50',
  default: 'bg-white/10 text-white border-white/20',
};

const sizeStyles: Record<BadgeSize, string> = {
  sm: 'px-2 py-0.5 text-xs',
  md: 'px-3 py-1 text-sm',
  lg: 'px-4 py-1.5 text-base',
};

const dotStyles: Record<BadgeVariant, string> = {
  success: 'bg-neon-500',
  warning: 'bg-yellow-500',
  danger: 'bg-red-500',
  info: 'bg-electric-500',
  default: 'bg-white',
};

export const Badge: React.FC<BadgeProps> = ({
  variant = 'default',
  size = 'md',
  dot = false,
  className = '',
  children,
  ...props
}) => {
  return (
    <span
      className={`
        inline-flex items-center gap-2
        rounded-full border
        font-medium
        ${variantStyles[variant]}
        ${sizeStyles[size]}
        ${className}
      `}
      {...props}
    >
      {dot && (
        <span className={`w-2 h-2 rounded-full ${dotStyles[variant]} animate-pulse`} />
      )}
      {children}
    </span>
  );
};
