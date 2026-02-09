import { motion, AnimatePresence } from 'framer-motion';
import { ReactNode } from 'react';
import { useLocation } from 'react-router-dom';
import { pageVariants, transitions, getAnimation } from '../../utils/animations';

type TransitionType = 'fade' | 'slide' | 'scale';

interface PageTransitionProps {
  children: ReactNode;
  type?: TransitionType;
  duration?: number;
}

export const PageTransition = ({ 
  children, 
  type = 'fade',
  duration = 0.3,
}: PageTransitionProps) => {
  const location = useLocation();
  const variants = getAnimation(pageVariants[type]);

  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={location.pathname}
        initial="initial"
        animate="animate"
        exit="exit"
        variants={variants}
        transition={{ duration, ...transitions.normal }}
      >
        {children}
      </motion.div>
    </AnimatePresence>
  );
};
