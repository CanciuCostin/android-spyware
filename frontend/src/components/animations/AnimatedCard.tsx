import { motion } from 'framer-motion';
import { ReactNode, HTMLAttributes } from 'react';
import { hoverLift, getTransition } from '../../utils/animations';

interface AnimatedCardProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  hover?: boolean;
  tilt?: boolean;
  glow?: boolean;
  className?: string;
}

export const AnimatedCard = ({
  children,
  hover = true,
  tilt = false,
  glow = false,
  className = '',
  ...props
}: AnimatedCardProps) => {
  return (
    <motion.div
      whileHover={
        hover
          ? {
              ...hoverLift,
              ...(tilt && {
                rotateY: 2,
                rotateX: 2,
              }),
            }
          : undefined
      }
      transition={getTransition({ duration: 0.3 })}
      className={`
        relative rounded-lg bg-gray-800/50 border border-gray-700
        backdrop-blur-sm
        ${glow ? 'hover:border-blue-500/50 hover:shadow-[0_0_20px_rgba(59,130,246,0.3)]' : ''}
        ${className}
      `}
      style={{
        transformStyle: 'preserve-3d',
      }}
      {...props}
    >
      {children}
      
      {glow && (
        <motion.div
          className="absolute inset-0 rounded-lg bg-gradient-to-r from-blue-500/10 to-purple-500/10 opacity-0"
          whileHover={{ opacity: 1 }}
          transition={{ duration: 0.3 }}
          style={{ pointerEvents: 'none' }}
        />
      )}
    </motion.div>
  );
};
