import { useRef, TouchEvent, MouseEvent } from 'react';

export interface LongPressConfig {
  onLongPress: () => void;
  delay?: number;
}

export const useLongPress = (config: LongPressConfig) => {
  const { onLongPress, delay = 500 } = config;
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  const start = () => {
    timerRef.current = setTimeout(() => {
      if (navigator.vibrate) {
        navigator.vibrate(50);
      }
      onLongPress();
    }, delay);
  };

  const cancel = () => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  };

  const onTouchStart = (_e: TouchEvent) => {
    start();
  };

  const onTouchEnd = (_e: TouchEvent) => {
    cancel();
  };

  const onMouseDown = (_e: MouseEvent) => {
    start();
  };

  const onMouseUp = (_e: MouseEvent) => {
    cancel();
  };

  const onMouseLeave = (_e: MouseEvent) => {
    cancel();
  };

  return {
    onTouchStart,
    onTouchEnd,
    onMouseDown,
    onMouseUp,
    onMouseLeave,
  };
};
