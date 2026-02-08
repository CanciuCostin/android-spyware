import { motion } from 'framer-motion';
import { shimmerVariants } from '../../utils/animations';

type SkeletonType = 'card' | 'list' | 'table' | 'text' | 'avatar' | 'custom';

interface SkeletonLoaderProps {
  type?: SkeletonType;
  count?: number;
  className?: string;
  width?: string;
  height?: string;
}

const shimmerStyle = {
  background: 'linear-gradient(90deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0.1) 50%, rgba(255,255,255,0.05) 100%)',
  backgroundSize: '200% 100%',
};

export const SkeletonLoader = ({
  type = 'card',
  count = 1,
  className = '',
  width,
  height,
}: SkeletonLoaderProps) => {
  const renderSkeleton = () => {
    switch (type) {
      case 'card':
        return (
          <motion.div
            variants={shimmerVariants}
            animate="shimmer"
            className={`rounded-lg bg-gray-800/50 p-4 ${className}`}
            style={{ ...shimmerStyle, width, height: height || '200px' }}
          >
            <div className="space-y-3">
              <div className="h-4 bg-gray-700/50 rounded w-3/4"></div>
              <div className="h-4 bg-gray-700/50 rounded w-1/2"></div>
              <div className="h-20 bg-gray-700/50 rounded w-full mt-4"></div>
            </div>
          </motion.div>
        );

      case 'list':
        return (
          <motion.div
            variants={shimmerVariants}
            animate="shimmer"
            className={`rounded-lg bg-gray-800/50 p-3 flex items-center gap-3 ${className}`}
            style={{ ...shimmerStyle, width, height: height || '60px' }}
          >
            <div className="h-10 w-10 bg-gray-700/50 rounded-full"></div>
            <div className="flex-1 space-y-2">
              <div className="h-3 bg-gray-700/50 rounded w-1/2"></div>
              <div className="h-3 bg-gray-700/50 rounded w-3/4"></div>
            </div>
          </motion.div>
        );

      case 'table':
        return (
          <motion.div
            variants={shimmerVariants}
            animate="shimmer"
            className={`rounded-lg bg-gray-800/50 p-3 ${className}`}
            style={{ ...shimmerStyle, width, height: height || '40px' }}
          >
            <div className="flex gap-4">
              <div className="h-4 bg-gray-700/50 rounded w-1/4"></div>
              <div className="h-4 bg-gray-700/50 rounded w-1/4"></div>
              <div className="h-4 bg-gray-700/50 rounded w-1/4"></div>
              <div className="h-4 bg-gray-700/50 rounded w-1/4"></div>
            </div>
          </motion.div>
        );

      case 'text':
        return (
          <motion.div
            variants={shimmerVariants}
            animate="shimmer"
            className={`h-4 bg-gray-700/50 rounded ${className}`}
            style={{ ...shimmerStyle, width: width || '100%', height: height || '16px' }}
          />
        );

      case 'avatar':
        return (
          <motion.div
            variants={shimmerVariants}
            animate="shimmer"
            className={`rounded-full bg-gray-700/50 ${className}`}
            style={{ 
              ...shimmerStyle, 
              width: width || '40px', 
              height: height || '40px',
            }}
          />
        );

      case 'custom':
        return (
          <motion.div
            variants={shimmerVariants}
            animate="shimmer"
            className={`bg-gray-800/50 rounded ${className}`}
            style={{ ...shimmerStyle, width, height }}
          />
        );

      default:
        return null;
    }
  };

  return (
    <>
      {Array.from({ length: count }).map((_, index) => (
        <div key={index} className={count > 1 ? 'mb-3' : ''}>
          {renderSkeleton()}
        </div>
      ))}
    </>
  );
};
