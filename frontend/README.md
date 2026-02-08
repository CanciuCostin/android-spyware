# EagleSpy V5 - Next-Gen UI Dashboard Frontend

Modern React + TypeScript + Vite frontend for the EagleSpy V5 Android Spyware C&C Dashboard.

## 🚀 Tech Stack

- **Framework**: React 19
- **Language**: TypeScript 5.9
- **Build Tool**: Vite 7
- **State Management**: Zustand
- **Routing**: React Router v7
- **HTTP Client**: Axios
- **Code Quality**: ESLint + Prettier

## 📁 Project Structure

```
frontend/
├── src/
│   ├── components/     # React components
│   ├── hooks/          # Custom React hooks
│   ├── services/       # API services (Axios)
│   ├── stores/         # Zustand stores
│   ├── types/          # TypeScript type definitions
│   ├── utils/          # Utility functions
│   ├── assets/         # Images, fonts, etc.
│   ├── App.tsx         # Main App component
│   └── main.tsx        # Entry point
├── public/             # Static assets
├── package.json
├── tsconfig.json       # TypeScript config
├── vite.config.ts      # Vite config
├── eslint.config.js    # ESLint config
└── .prettierrc.json    # Prettier config
```

## 🛠️ Setup & Installation

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## 📜 Available Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server (http://localhost:5173) |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run lint` | Lint code with ESLint |
| `npm run lint:fix` | Auto-fix ESLint issues |
| `npm run format` | Format code with Prettier |
| `npm run format:check` | Check code formatting |
| `npm run type-check` | TypeScript type checking |

## ⚙️ Configuration

### TypeScript Path Aliases

Configured path aliases for cleaner imports:

```typescript
import MyComponent from '@components/MyComponent';
import { useMyHook } from '@hooks/useMyHook';
import { apiService } from '@services/api';
import { useAppStore } from '@stores/appStore';
import { Device } from '@types/index';
import { formatDate } from '@utils/helpers';
import logo from '@assets/logo.png';
```

### API Proxy

Vite is configured to proxy API requests to the Rails backend:

```typescript
// vite.config.ts
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:3000',
      changeOrigin: true,
    },
  },
}
```

### Environment Variables

Create a `.env` file in the frontend directory:

```env
VITE_API_BASE_URL=http://localhost:3000/api
```

## 🎯 Key Features

### 1. **API Service** (`src/services/api.ts`)
- Centralized Axios instance
- Request/response interceptors
- Type-safe API calls
- Error handling

### 2. **State Management** (`src/stores/appStore.ts`)
- Zustand for lightweight global state
- Type-safe store definitions
- Simple and performant

### 3. **TypeScript Types** (`src/types/index.ts`)
- Shared type definitions
- API response types
- Domain models

### 4. **Utilities** (`src/utils/helpers.ts`)
- Common helper functions
- Date formatting
- Reusable logic

## 🔥 Development Workflow

1. **Start the Rails API** (in project root):
   ```bash
   docker-compose up -d
   # or
   rails server
   ```

2. **Start the Vite dev server** (in frontend/):
   ```bash
   npm run dev
   ```

3. **Access the dashboard**:
   - Frontend: http://localhost:5173
   - API: http://localhost:3000

4. **Make changes**:
   - Edit files in `src/`
   - Hot Module Replacement (HMR) automatically updates the browser

5. **Lint & Format before committing**:
   ```bash
   npm run lint:fix
   npm run format
   ```

## 🏗️ Next Steps (ФАЗА 1+)

- [ ] Implement authentication flow
- [ ] Create device list/dashboard components
- [ ] Build real-time WebSocket/WebRTC connections
- [ ] Add responsive UI components
- [ ] Implement routing with React Router
- [ ] Create command execution interface
- [ ] Add file upload/download features
- [ ] Build real-time monitoring panels

## 📝 Notes

- **Port**: Frontend runs on `5173`, Rails API on `3000`
- **Proxy**: All `/api/*` requests are proxied to Rails backend
- **HMR**: Hot Module Replacement enabled for fast development
- **Strict Mode**: TypeScript strict mode is enabled for type safety

## 🐛 Troubleshooting

### Port already in use
```bash
# Kill process on port 5173
npx kill-port 5173
```

### Module resolution issues
```bash
# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm install
```

### TypeScript errors
```bash
# Run type check
npm run type-check
```

---

**Built with ❤️ for EagleSpy V5**

