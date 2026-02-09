import { useAppStore } from '@stores/appStore';

const HelloWorld = () => {
  const { isLoading, setLoading } = useAppStore();

  const handleClick = () => {
    setLoading(!isLoading);
  };

  return (
    <div style={{ textAlign: 'center', padding: '2rem' }}>
      <h1>🚀 Next-Gen UI Dashboard</h1>
      <p>Welcome to the EagleSpy V5 Frontend!</p>
      <p>Status: {isLoading ? '⏳ Loading...' : '✅ Ready'}</p>
      <button
        onClick={handleClick}
        style={{
          padding: '0.5rem 1rem',
          marginTop: '1rem',
          cursor: 'pointer',
          fontSize: '1rem',
        }}
      >
        Toggle Loading State
      </button>
      <div style={{ marginTop: '2rem', textAlign: 'left', maxWidth: '600px', margin: '2rem auto' }}>
        <h3>✨ Features Configured:</h3>
        <ul>
          <li>✅ Vite + React + TypeScript</li>
          <li>✅ ESLint + Prettier</li>
          <li>✅ React Router (installed)</li>
          <li>✅ Axios for API calls</li>
          <li>✅ Zustand for state management</li>
          <li>✅ Path aliases (@components, @hooks, @services, @stores, @types, @utils, @assets)</li>
          <li>✅ Proxy to Rails API (localhost:3000)</li>
        </ul>
      </div>
    </div>
  );
};

export default HelloWorld;
