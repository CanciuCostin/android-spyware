import { motion } from 'framer-motion';
import { ReactNode, ButtonHTMLAttributes } from 'react';
import { hoverScale, tapScale, getTransition } from '../../utils/animations';
import { PulseLoader } from './PulseLoader';

interface AnimatedButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
  ripple?: boolean;
  className?: string;
}

const variantStyles = {
  primary: 'bg-blue-600 hover:bg-blue-700 text-white',
  secondary: 'bg-gray-700 hover:bg-gray-600 text-white',
  danger: 'bg-red-600 hover:bg-red-700 text-white',
  ghost: 'bg-transparent hover:bg-gray-800 text-gray-300',
};

const sizeStyles = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-6 py-3 text-lg',
};

export const AnimatedButton = ({
  children,
  variant = 'primary',
  size = 'md',
  loading = false,
  ripple = true,
  className = '',
  disabled,
  ...props
}: AnimatedButtonProps) => {
  const isDisabled = disabled || loading;

  return (
    <motion.button
      whileHover={!isDisabled ? hoverScale : undefined}
      whileTap={!isDisabled ? tapScale : undefined}
      transition={getTransition({ duration: 0.15 })}
      className={`
        relative rounded-lg font-medium
        transition-colors duration-200
        disabled:opacity-50 disabled:cursor-not-allowed
        focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-gray-900
        ${variantStyles[variant]}
        ${sizeStyles[size]}
        ${className}
      `}
      disabled={isDisabled}
      {...props}
    >
      {loading ? (
        <span className="flex items-center justify-center gap-2">
          <PulseLoader size="sm" color="bg-current" />
          <span className="opacity-70">Loading...</span>
        </span>
      ) : (
        children
      )}
      
      {ripple && !isDisabled && (
        <motion.span
          className="absolute inset-0 rounded-lg"
          initial={{ scale: 0, opacity: 0.5 }}
          whileTap={{ scale: 2, opacity: 0 }}
          transition={{ duration: 0.4 }}
          style={{ background: 'rgba(255, 255, 255, 0.3)' }}
        />
      )}
    </motion.button>
  );
};
