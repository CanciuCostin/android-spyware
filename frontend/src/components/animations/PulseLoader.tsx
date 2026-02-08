import { motion } from 'framer-motion';
import { pulseVariants } from '../../utils/animations';

interface PulseLoaderProps {
  size?: 'sm' | 'md' | 'lg';
  color?: string;
  count?: number;
  className?: string;
}

const sizeMap = {
  sm: 'w-2 h-2',
  md: 'w-3 h-3',
  lg: 'w-4 h-4',
};

export const PulseLoader = ({
  size = 'md',
  color = 'bg-blue-500',
  count = 3,
  className = '',
}: PulseLoaderProps) => {
  return (
    <div className={`flex items-center gap-2 ${className}`}>
      {Array.from({ length: count }).map((_, index) => (
        <motion.div
          key={index}
          variants={pulseVariants}
          animate="pulse"
          transition={{
            delay: index * 0.2,
            duration: 1.5,
            repeat: Infinity,
          }}
          className={`${sizeMap[size]} ${color} rounded-full`}
        />
      ))}
    </div>
  );
};
