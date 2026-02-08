import { Variants, Transition } from 'framer-motion';

// Check if user prefers reduced motion
export const prefersReducedMotion = (): boolean => {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
};

// Common easing functions
export const easings = {
  easeInOut: [0.4, 0, 0.2, 1],
  easeOut: [0, 0, 0.2, 1],
  easeIn: [0.4, 0, 1, 1],
  sharp: [0.4, 0, 0.6, 1],
  bounce: [0.68, -0.55, 0.265, 1.55],
};

// Common transition configurations
export const transitions = {
  fast: { duration: 0.15, ease: easings.easeOut },
  normal: { duration: 0.3, ease: easings.easeInOut },
  slow: { duration: 0.5, ease: easings.easeInOut },
  bounce: { duration: 0.6, ease: easings.bounce },
};

// Fade animation variants
export const fadeVariants: Variants = {
  hidden: { opacity: 0 },
  visible: { 
    opacity: 1,
    transition: transitions.normal,
  },
  exit: { 
    opacity: 0,
    transition: transitions.fast,
  },
};

// Slide animation variants
export const slideVariants = {
  fromTop: {
    hidden: { opacity: 0, y: -20 },
    visible: { 
      opacity: 1, 
      y: 0,
      transition: transitions.normal,
    },
    exit: { 
      opacity: 0, 
      y: -20,
      transition: transitions.fast,
    },
  },
  fromBottom: {
    hidden: { opacity: 0, y: 20 },
    visible: { 
      opacity: 1, 
      y: 0,
      transition: transitions.normal,
    },
    exit: { 
      opacity: 0, 
      y: 20,
      transition: transitions.fast,
    },
  },
  fromLeft: {
    hidden: { opacity: 0, x: -20 },
    visible: { 
      opacity: 1, 
      x: 0,
      transition: transitions.normal,
    },
    exit: { 
      opacity: 0, 
      x: -20,
      transition: transitions.fast,
    },
  },
  fromRight: {
    hidden: { opacity: 0, x: 20 },
    visible: { 
      opacity: 1, 
      x: 0,
      transition: transitions.normal,
    },
    exit: { 
      opacity: 0, 
      x: 20,
      transition: transitions.fast,
    },
  },
};

// Scale animation variants
export const scaleVariants: Variants = {
  hidden: { opacity: 0, scale: 0.9 },
  visible: { 
    opacity: 1, 
    scale: 1,
    transition: transitions.normal,
  },
  exit: { 
    opacity: 0, 
    scale: 0.9,
    transition: transitions.fast,
  },
};

// Scale with bounce
export const scaleBounceVariants: Variants = {
  hidden: { opacity: 0, scale: 0.8 },
  visible: { 
    opacity: 1, 
    scale: 1,
    transition: transitions.bounce,
  },
  exit: { 
    opacity: 0, 
    scale: 0.8,
    transition: transitions.fast,
  },
};

// Stagger configurations
export const staggerContainers = {
  fast: {
    visible: {
      transition: {
        staggerChildren: 0.05,
      },
    },
  },
  normal: {
    visible: {
      transition: {
        staggerChildren: 0.1,
      },
    },
  },
  slow: {
    visible: {
      transition: {
        staggerChildren: 0.2,
      },
    },
  },
};

// Hover and tap animations
export const hoverScale = {
  scale: 1.05,
  transition: transitions.fast,
};

export const tapScale = {
  scale: 0.95,
  transition: transitions.fast,
};

export const hoverLift = {
  y: -4,
  boxShadow: '0 10px 30px rgba(0, 0, 0, 0.3)',
  transition: transitions.normal,
};

// Page transition variants
export const pageVariants = {
  fade: {
    initial: { opacity: 0 },
    animate: { opacity: 1 },
    exit: { opacity: 0 },
  },
  slide: {
    initial: { opacity: 0, x: 20 },
    animate: { opacity: 1, x: 0 },
    exit: { opacity: 0, x: -20 },
  },
  scale: {
    initial: { opacity: 0, scale: 0.95 },
    animate: { opacity: 1, scale: 1 },
    exit: { opacity: 0, scale: 1.05 },
  },
};

// Shimmer effect keyframes
export const shimmerVariants: Variants = {
  shimmer: {
    backgroundPosition: ['200% 0', '-200% 0'],
    transition: {
      duration: 2,
      repeat: Infinity,
      ease: 'linear',
    },
  },
};

// Pulse animation
export const pulseVariants: Variants = {
  pulse: {
    scale: [1, 1.1, 1],
    opacity: [1, 0.8, 1],
    transition: {
      duration: 1.5,
      repeat: Infinity,
      ease: 'easeInOut',
    },
  },
};

// Spin animation
export const spinVariants: Variants = {
  spin: {
    rotate: 360,
    transition: {
      duration: 1,
      repeat: Infinity,
      ease: 'linear',
    },
  },
};

// Helper function to get animation with reduced motion support
export const getAnimation = (variants: Variants, shouldAnimate: boolean = true): Variants => {
  if (!shouldAnimate || prefersReducedMotion()) {
    return {
      hidden: {},
      visible: {},
      exit: {},
    };
  }
  return variants;
};

// Helper to get transition with reduced motion support
export const getTransition = (transition: Transition): Transition => {
  if (prefersReducedMotion()) {
    return { duration: 0.01 };
  }
  return transition;
};
