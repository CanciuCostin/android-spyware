import React, { type InputHTMLAttributes, forwardRef } from 'react';

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  helperText?: string;
  icon?: React.ReactNode;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, helperText, icon, className = '', id, ...props }, ref) => {
    const inputId = id || `input-${Math.random().toString(36).substr(2, 9)}`;
    const errorId = error ? `${inputId}-error` : undefined;
    const helperTextId = helperText ? `${inputId}-helper` : undefined;
    
    const inputStyles = error
      ? 'border-red-500 focus:ring-red-500'
      : 'border-white/20 focus:ring-electric-500 focus:border-electric-500';

    return (
      <div className="w-full">
        {label && (
          <label htmlFor={inputId} className="block text-sm font-medium text-white/80 mb-2">
            {label}
          </label>
        )}
        <div className="relative">
          {icon && (
            <div className="absolute left-3 top-1/2 -translate-y-1/2 text-white/50" aria-hidden="true">
              {icon}
            </div>
          )}
          <input
            ref={ref}
            id={inputId}
            className={`
              w-full px-4 py-2 rounded-lg
              bg-white/5 backdrop-blur-sm
              border ${inputStyles}
              text-white placeholder:text-white/40
              focus:outline-none focus:ring-2 focus:ring-opacity-50
              transition-all duration-300
              disabled:opacity-50 disabled:cursor-not-allowed
              ${icon ? 'pl-10' : ''}
              ${className}
            `}
            aria-invalid={error ? 'true' : 'false'}
            aria-describedby={error ? errorId : helperTextId}
            {...props}
          />
        </div>
        {error && (
          <p id={errorId} className="mt-1 text-sm text-red-500" role="alert">{error}</p>
        )}
        {helperText && !error && (
          <p id={helperTextId} className="mt-1 text-sm text-white/60">{helperText}</p>
        )}
      </div>
    );
  }
);

Input.displayName = 'Input';
