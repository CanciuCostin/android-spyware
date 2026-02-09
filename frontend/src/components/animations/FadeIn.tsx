import { motion } from 'framer-motion';
import { ReactNode } from 'react';
import { fadeVariants, staggerContainers, getAnimation } from '../../utils/animations';

interface FadeInProps {
  children: ReactNode;
  delay?: number;
  duration?: number;
  stagger?: boolean;
  staggerDelay?: 'fast' | 'normal' | 'slow';
  className?: string;
}

export const FadeIn = ({
  children,
  delay = 0,
  duration = 0.3,
  stagger = false,
  staggerDelay = 'normal',
  className = '',
}: FadeInProps) => {
  const variants = getAnimation(fadeVariants);
  const containerVariants = stagger ? staggerContainers[staggerDelay] : undefined;

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      exit="exit"
      variants={stagger ? containerVariants : variants}
      transition={{ delay, duration }}
      className={className}
    >
      {children}
    </motion.div>
  );
};

interface FadeInItemProps {
  children: ReactNode;
  className?: string;
}

export const FadeInItem = ({ children, className = '' }: FadeInItemProps) => {
  const variants = getAnimation(fadeVariants);
  
  return (
    <motion.div variants={variants} className={className}>
      {children}
    </motion.div>
  );
};
