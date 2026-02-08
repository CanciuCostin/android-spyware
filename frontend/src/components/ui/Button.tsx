import React, { type ButtonHTMLAttributes, forwardRef } from 'react';
import { motion } from 'framer-motion';
import { hoverScale, tapScale, getTransition } from '../../utils/animations';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  isLoading?: boolean;
  icon?: React.ReactNode;
  fullWidth?: boolean;
  animated?: boolean;
}

const variantStyles: Record<ButtonVariant, string> = {
  primary: 'bg-theme-primary hover:opacity-90 text-white shadow-md',
  secondary: 'theme-bg-elevated hover:bg-theme-primary/10 theme-text border-2 border-theme-border',
  ghost: 'bg-transparent hover:bg-theme-primary/10 theme-text',
  danger: 'bg-red-500 hover:bg-red-600 text-white',
};

const sizeStyles: Record<ButtonSize, string> = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-6 py-3 text-lg',
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      variant = 'primary',
      size = 'md',
      isLoading = false,
      icon,
      fullWidth = false,
      animated = true,
      className = '',
      children,
      disabled,
      ...props
    },
    ref
  ) => {
    const baseStyles = 'inline-flex items-center justify-center gap-2 rounded-lg font-medium transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed theme-transition';
    const widthStyles = fullWidth ? 'w-full' : '';
    const isDisabled = disabled || isLoading;

    const ButtonComponent = animated ? motion.button : 'button';
    const motionProps = animated && !isDisabled ? {
      whileHover: hoverScale,
      whileTap: tapScale,
      transition: getTransition({ duration: 0.15 }),
    } : {};

    return (
      <ButtonComponent
        ref={ref as any}
        className={`${baseStyles} ${variantStyles[variant]} ${sizeStyles[size]} ${widthStyles} ${className}`}
        disabled={isDisabled}
        aria-busy={isLoading}
        aria-disabled={isDisabled}
        {...motionProps}
        {...props}
      >
        {isLoading ? (
          <>
            <svg 
              className="animate-spin h-5 w-5" 
              xmlns="http://www.w3.org/2000/svg" 
              fill="none" 
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span>Loading...</span>
          </>
        ) : (
          <>
            {icon && <span aria-hidden="true">{icon}</span>}
            {children}
          </>
        )}
      </ButtonComponent>
    );
  }
);

Button.displayName = 'Button';
