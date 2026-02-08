import { Component, ErrorInfo, ReactNode } from 'react';

interface ErrorBoundaryProps {
  children: ReactNode;
  fallback?: ReactNode | ((error: Error) => ReactNode);
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
    };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return {
      hasError: true,
      error,
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('ErrorBoundary caught an error:', error, errorInfo);
    
    if (this.props.onError) {
      this.props.onError(error, errorInfo);
    }
  }

  render() {
    if (this.state.hasError && this.state.error) {
      if (this.props.fallback) {
        return typeof this.props.fallback === 'function'
          ? this.props.fallback(this.state.error)
          : this.props.fallback;
      }

      return (
        <div
          style={{
            padding: '2rem',
            backgroundColor: 'var(--color-error-bg, #fee)',
            border: '1px solid var(--color-error, #c00)',
            borderRadius: '8px',
            margin: '1rem',
          }}
          role="alert"
        >
          <h2 style={{ marginTop: 0 }}>Something went wrong</h2>
          <details style={{ cursor: 'pointer' }}>
            <summary>Error details</summary>
            <pre
              style={{
                marginTop: '1rem',
                padding: '1rem',
                backgroundColor: 'var(--color-background, #fff)',
                borderRadius: '4px',
                overflow: 'auto',
              }}
            >
              {this.state.error.message}
              {'\n\n'}
              {this.state.error.stack}
            </pre>
          </details>
          <button
            onClick={() => window.location.reload()}
            style={{
              marginTop: '1rem',
              padding: '0.5rem 1rem',
              backgroundColor: 'var(--color-primary, #007bff)',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
            }}
          >
            Reload page
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
