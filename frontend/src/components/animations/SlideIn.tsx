import { motion } from 'framer-motion';
import { ReactNode } from 'react';
import { slideVariants, getAnimation } from '../../utils/animations';

type Direction = 'top' | 'bottom' | 'left' | 'right';

interface SlideInProps {
  children: ReactNode;
  direction?: Direction;
  distance?: number;
  delay?: number;
  duration?: number;
  className?: string;
}

export const SlideIn = ({
  children,
  direction = 'bottom',
  distance = 20,
  delay = 0,
  duration = 0.3,
  className = '',
}: SlideInProps) => {
  const directionMap: Record<Direction, keyof typeof slideVariants> = {
    top: 'fromTop',
    bottom: 'fromBottom',
    left: 'fromLeft',
    right: 'fromRight',
  };

  const variants = getAnimation(slideVariants[directionMap[direction]]);
  
  // Adjust distance if custom value provided
  const customVariants = distance !== 20 ? {
    hidden: {
      opacity: 0,
      [direction === 'top' || direction === 'bottom' ? 'y' : 'x']: 
        direction === 'top' || direction === 'left' ? -distance : distance,
    },
    visible: {
      opacity: 1,
      x: 0,
      y: 0,
    },
    exit: {
      opacity: 0,
      [direction === 'top' || direction === 'bottom' ? 'y' : 'x']: 
        direction === 'top' || direction === 'left' ? -distance : distance,
    },
  } : variants;

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      exit="exit"
      variants={customVariants}
      transition={{ delay, duration }}
      className={className}
    >
      {children}
    </motion.div>
  );
};
