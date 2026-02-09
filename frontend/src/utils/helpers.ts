export const formatDate = (date: string | Date): string => {
  return new Date(date).toLocaleString();
};

export const delay = (ms: number): Promise<void> => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};
