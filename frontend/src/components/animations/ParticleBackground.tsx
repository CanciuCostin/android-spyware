import { motion } from 'framer-motion';
import { useEffect, useState, useMemo } from 'react';

type ParticleEffect = 'float' | 'grid' | 'cyber';

interface Particle {
  id: number;
  x: number;
  y: number;
  size: number;
  duration: number;
  delay: number;
}

interface ParticleBackgroundProps {
  effect?: ParticleEffect;
  density?: 'low' | 'medium' | 'high';
  color?: string;
  speed?: number;
  className?: string;
}

const densityMap = {
  low: 20,
  medium: 40,
  high: 60,
};

export const ParticleBackground = ({
  effect = 'float',
  density = 'medium',
  color = 'rgba(59, 130, 246, 0.5)',
  speed = 1,
  className = '',
}: ParticleBackgroundProps) => {
  const [dimensions, setDimensions] = useState({ width: 0, height: 0 });
  const particleCount = densityMap[density];

  useEffect(() => {
    const updateDimensions = () => {
      setDimensions({
        width: window.innerWidth,
        height: window.innerHeight,
      });
    };

    updateDimensions();
    window.addEventListener('resize', updateDimensions);
    return () => window.removeEventListener('resize', updateDimensions);
  }, []);

  const particles = useMemo(() => {
    return Array.from({ length: particleCount }, (_, i) => ({
      id: i,
      x: Math.random() * 100,
      y: Math.random() * 100,
      size: Math.random() * 3 + 1,
      duration: (Math.random() * 10 + 10) / speed,
      delay: Math.random() * 2,
    }));
  }, [particleCount, speed]);

  if (effect === 'float') {
    return (
      <div className={`fixed inset-0 overflow-hidden pointer-events-none ${className}`}>
        {particles.map((particle) => (
          <motion.div
            key={particle.id}
            className="absolute rounded-full"
            style={{
              left: `${particle.x}%`,
              top: `${particle.y}%`,
              width: particle.size,
              height: particle.size,
              background: color,
              boxShadow: `0 0 ${particle.size * 2}px ${color}`,
            }}
            animate={{
              y: [0, -30, 0],
              x: [0, Math.random() * 20 - 10, 0],
              opacity: [0.2, 0.5, 0.2],
            }}
            transition={{
              duration: particle.duration,
              delay: particle.delay,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
          />
        ))}
      </div>
    );
  }

  if (effect === 'grid') {
    const gridLines = 20;
    return (
      <div className={`fixed inset-0 overflow-hidden pointer-events-none ${className}`}>
        <svg width="100%" height="100%" className="opacity-20">
          <defs>
            <pattern id="grid" width="50" height="50" patternUnits="userSpaceOnUse">
              <motion.path
                d="M 50 0 L 0 0 0 50"
                fill="none"
                stroke={color}
                strokeWidth="0.5"
                animate={{
                  opacity: [0.3, 0.6, 0.3],
                }}
                transition={{
                  duration: 3 / speed,
                  repeat: Infinity,
                  ease: 'easeInOut',
                }}
              />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)" />
        </svg>
      </div>
    );
  }

  if (effect === 'cyber') {
    return (
      <div className={`fixed inset-0 overflow-hidden pointer-events-none ${className}`}>
        {/* Cyber grid background */}
        <svg width="100%" height="100%" className="opacity-10">
          <defs>
            <pattern id="cyber-grid" width="40" height="40" patternUnits="userSpaceOnUse">
              <path
                d="M 40 0 L 0 0 0 40"
                fill="none"
                stroke={color}
                strokeWidth="1"
              />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#cyber-grid)" />
        </svg>

        {/* Animated scan lines */}
        {[0, 1, 2].map((i) => (
          <motion.div
            key={i}
            className="absolute w-full h-px"
            style={{
              background: `linear-gradient(90deg, transparent, ${color}, transparent)`,
              boxShadow: `0 0 10px ${color}`,
            }}
            animate={{
              top: ['0%', '100%'],
              opacity: [0, 1, 0],
            }}
            transition={{
              duration: 4 / speed,
              delay: i * 1.5,
              repeat: Infinity,
              ease: 'linear',
            }}
          />
        ))}

        {/* Floating particles */}
        {particles.slice(0, 10).map((particle) => (
          <motion.div
            key={particle.id}
            className="absolute"
            style={{
              left: `${particle.x}%`,
              top: `${particle.y}%`,
            }}
          >
            <motion.div
              className="w-1 h-1 rounded-full"
              style={{
                background: color,
                boxShadow: `0 0 10px ${color}`,
              }}
              animate={{
                scale: [1, 1.5, 1],
                opacity: [0.3, 0.8, 0.3],
              }}
              transition={{
                duration: particle.duration / 2,
                delay: particle.delay,
                repeat: Infinity,
              }}
            />
          </motion.div>
        ))}
      </div>
    );
  }

  return null;
};
