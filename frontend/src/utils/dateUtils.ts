// Simple date utility to format relative time without external dependencies

export function formatDistanceToNow(date: Date | string, options?: { addSuffix?: boolean }): string {
  const now = new Date();
  const targetDate = typeof date === 'string' ? new Date(date) : date;
  
  const diffMs = now.getTime() - targetDate.getTime();
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);
  const diffMonths = Math.floor(diffDays / 30);
  const diffYears = Math.floor(diffDays / 365);

  let result = '';

  if (diffYears > 0) {
    result = `${diffYears} year${diffYears > 1 ? 's' : ''}`;
  } else if (diffMonths > 0) {
    result = `${diffMonths} month${diffMonths > 1 ? 's' : ''}`;
  } else if (diffDays > 0) {
    result = `${diffDays} day${diffDays > 1 ? 's' : ''}`;
  } else if (diffHours > 0) {
    result = `${diffHours} hour${diffHours > 1 ? 's' : ''}`;
  } else if (diffMinutes > 0) {
    result = `${diffMinutes} minute${diffMinutes > 1 ? 's' : ''}`;
  } else {
    result = 'a few seconds';
  }

  return options?.addSuffix ? `${result} ago` : result;
}
