import React, { type ImgHTMLAttributes } from 'react';

export interface AvatarProps extends Omit<ImgHTMLAttributes<HTMLImageElement>, 'src'> {
  src?: string;
  alt?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  fallback?: string;
  status?: 'online' | 'offline' | 'away' | 'busy' | 'idle';
}

const sizeStyles = {
  sm: 'w-8 h-8 text-xs',
  md: 'w-12 h-12 text-sm',
  lg: 'w-16 h-16 text-base',
  xl: 'w-24 h-24 text-xl',
};

const statusStyles = {
  online: 'bg-neon-500',
  offline: 'bg-gray-500',
  away: 'bg-yellow-500',
  busy: 'bg-red-500',
  idle: 'bg-yellow-500',
};

export const Avatar: React.FC<AvatarProps> = ({
  src,
  alt = 'Avatar',
  size = 'md',
  fallback,
  status,
  className = '',
  ...props
}) => {
  const [imageError, setImageError] = React.useState(false);

  const initials = React.useMemo(() => {
    if (fallback) return fallback;
    const name = alt || '';
    return name
      .split(' ')
      .map((n) => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  }, [alt, fallback]);

  return (
    <div className={`relative inline-block ${className}`}>
      <div
        className={`
          ${sizeStyles[size]}
          rounded-full overflow-hidden
          bg-gradient-to-br from-electric-500 to-cyber-500
          flex items-center justify-center
          font-semibold text-white
        `}
      >
        {src && !imageError ? (
          <img
            src={src}
            alt={alt}
            className="w-full h-full object-cover"
            onError={() => setImageError(true)}
            {...props}
          />
        ) : (
          <span>{initials}</span>
        )}
      </div>

      {status && (
        <span
          className={`
            absolute bottom-0 right-0
            w-3 h-3 rounded-full border-2 border-dark-950
            ${statusStyles[status]}
          `}
        />
      )}
    </div>
  );
};
