import React, { type HTMLAttributes } from 'react';
import { motion } from 'framer-motion';
import { hoverLift, getTransition } from '../../utils/animations';

export type CardVariant = 'default' | 'glass' | 'dark' | 'gradient';

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: CardVariant;
  hover?: boolean;
  animated?: boolean;
}

const variantStyles: Record<CardVariant, string> = {
  default: 'theme-bg-card border border-theme-border',
  glass: 'glass border border-theme-border',
  dark: 'glass-dark border border-theme-border',
  gradient: 'bg-gradient-to-br from-theme-primary/10 to-theme-secondary/10 border border-theme-border',
};

export const Card: React.FC<CardProps> = ({
  variant = 'default',
  hover = false,
  animated = true,
  className = '',
  children,
  ...props
}) => {
  const hoverStyles = hover ? 'hover:shadow-glass hover:scale-[1.02] cursor-pointer' : '';
  
  const CardComponent = animated && hover ? motion.div : 'div';
  const motionProps = animated && hover ? {
    whileHover: hoverLift,
    transition: getTransition({ duration: 0.3 }),
  } : {};

  return (
    <CardComponent
      className={`
        rounded-xl p-6
        ${variantStyles[variant]}
        ${hoverStyles}
        transition-all duration-300 theme-transition
        ${className}
      `}
      {...motionProps}
      {...props}
    >
      {children}
    </CardComponent>
  );
};

export const CardHeader: React.FC<HTMLAttributes<HTMLDivElement>> = ({
  className = '',
  children,
  ...props
}) => (
  <div className={`mb-4 ${className}`} {...props}>
    {children}
  </div>
);

export const CardTitle: React.FC<HTMLAttributes<HTMLHeadingElement>> = ({
  className = '',
  children,
  ...props
}) => (
  <h3 className={`text-xl font-semibold theme-text ${className}`} {...props}>
    {children}
  </h3>
);

export const CardContent: React.FC<HTMLAttributes<HTMLDivElement>> = ({
  className = '',
  children,
  ...props
}) => (
  <div className={`theme-text-muted ${className}`} {...props}>
    {children}
  </div>
);

export const CardFooter: React.FC<HTMLAttributes<HTMLDivElement>> = ({
  className = '',
  children,
  ...props
}) => (
  <div className={`mt-4 pt-4 border-t border-theme-border ${className}`} {...props}>
    {children}
  </div>
);
