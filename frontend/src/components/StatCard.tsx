import React from 'react';
import { Card, CardContent } from './ui';

export interface StatCardProps {
  title: string;
  value: string | number;
  change?: {
    value: number;
    type: 'increase' | 'decrease';
  };
  icon?: React.ReactNode;
  variant?: 'electric' | 'cyber' | 'neon' | 'default';
}

const variantStyles = {
  electric: {
    bg: 'bg-electric-500/10',
    text: 'text-electric-400',
    glow: 'glow-electric',
  },
  cyber: {
    bg: 'bg-cyber-500/10',
    text: 'text-cyber-400',
    glow: 'glow-cyber',
  },
  neon: {
    bg: 'bg-neon-500/10',
    text: 'text-neon-400',
    glow: 'glow-neon',
  },
  default: {
    bg: 'bg-white/5',
    text: 'text-white',
    glow: '',
  },
};

export const StatCard: React.FC<StatCardProps> = ({
  title,
  value,
  change,
  icon,
  variant = 'default',
}) => {
  const styles = variantStyles[variant];

  return (
    <Card variant="glass" hover className={styles.glow}>
      <CardContent className="p-6">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <p className="text-sm text-white/60 mb-1">{title}</p>
            <p className={`text-3xl font-bold ${styles.text}`}>{value}</p>
            {change && (
              <div className="flex items-center gap-1 mt-2">
                {change.type === 'increase' ? (
                  <svg className="w-4 h-4 text-neon-500" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M5.293 9.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 7.414V15a1 1 0 11-2 0V7.414L6.707 9.707a1 1 0 01-1.414 0z" clipRule="evenodd" />
                  </svg>
                ) : (
                  <svg className="w-4 h-4 text-red-500" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M14.707 10.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 12.586V5a1 1 0 012 0v7.586l2.293-2.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                )}
                <span
                  className={`text-sm ${
                    change.type === 'increase' ? 'text-neon-500' : 'text-red-500'
                  }`}
                >
                  {Math.abs(change.value)}%
                </span>
              </div>
            )}
          </div>
          {icon && (
            <div className={`p-3 rounded-lg ${styles.bg} ${styles.text}`}>
              {icon}
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
};
