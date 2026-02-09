import { motion } from 'framer-motion';
import { useEffect, useState } from 'react';

type ProgressVariant = 'primary' | 'success' | 'warning' | 'error';

interface ProgressBarProps {
  progress?: number; // 0-100, undefined for indeterminate
  variant?: ProgressVariant;
  height?: string;
  className?: string;
  showLabel?: boolean;
}

const variantColors: Record<ProgressVariant, string> = {
  primary: 'bg-blue-500',
  success: 'bg-green-500',
  warning: 'bg-yellow-500',
  error: 'bg-red-500',
};

export const ProgressBar = ({
  progress,
  variant = 'primary',
  height = 'h-2',
  className = '',
  showLabel = false,
}: ProgressBarProps) => {
  const [animatedProgress, setAnimatedProgress] = useState(0);
  const isIndeterminate = progress === undefined;

  useEffect(() => {
    if (progress !== undefined) {
      setAnimatedProgress(progress);
    }
  }, [progress]);

  if (isIndeterminate) {
    return (
      <div className={`relative overflow-hidden bg-gray-800 rounded-full ${height} ${className}`}>
        <motion.div
          className={`absolute inset-y-0 left-0 ${variantColors[variant]} rounded-full`}
          style={{ width: '30%' }}
          animate={{
            x: ['-100%', '400%'],
          }}
          transition={{
            duration: 1.5,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        />
      </div>
    );
  }

  return (
    <div className={`relative ${className}`}>
      {showLabel && (
        <div className="flex justify-between mb-1 text-xs text-gray-400">
          <span>Progress</span>
          <span>{Math.round(animatedProgress)}%</span>
        </div>
      )}
      <div className={`relative overflow-hidden bg-gray-800 rounded-full ${height}`}>
        <motion.div
          className={`absolute inset-y-0 left-0 ${variantColors[variant]} rounded-full`}
          initial={{ width: 0 }}
          animate={{ width: `${animatedProgress}%` }}
          transition={{
            duration: 0.5,
            ease: 'easeOut',
          }}
        />
      </div>
    </div>
  );
};
