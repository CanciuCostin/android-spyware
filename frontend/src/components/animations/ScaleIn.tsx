import { motion } from 'framer-motion';
import { ReactNode } from 'react';
import { scaleVariants, scaleBounceVariants, getAnimation } from '../../utils/animations';

interface ScaleInProps {
  children: ReactNode;
  bounce?: boolean;
  delay?: number;
  duration?: number;
  initialScale?: number;
  className?: string;
}

export const ScaleIn = ({
  children,
  bounce = false,
  delay = 0,
  duration = 0.3,
  initialScale = 0.9,
  className = '',
}: ScaleInProps) => {
  const variants = getAnimation(bounce ? scaleBounceVariants : scaleVariants);
  
  // Adjust initial scale if custom value provided
  const customVariants = initialScale !== 0.9 && !bounce ? {
    hidden: { opacity: 0, scale: initialScale },
    visible: { opacity: 1, scale: 1 },
    exit: { opacity: 0, scale: initialScale },
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
