import { BrowserRouter, Routes, Route, useLocation } from 'react-router-dom';
import { MainLayout } from './components/layout';
import { Dashboard } from './pages/Dashboard';
import { DashboardPage } from './pages/DashboardPage';
import { DevicesPage } from './pages/DevicesPage';
import { DeviceDetail } from './pages/Devices/DeviceDetail';
import { CommandsPage } from './pages/CommandsPage';
import { AnalyticsPage } from './pages/AnalyticsPage';
import { SettingsPage } from './pages/SettingsPage';
import { NotificationDemo } from './pages/NotificationDemo';
import { AnimationsDemo } from './pages/AnimationsDemo';
import { AdvancedDemo } from './pages/AdvancedDemo';
import { PageTransition } from './components/animations';
import { ErrorBoundary } from './components/performance';
import { SkipLink } from './components/a11y';
import './App.css';

function AppRoutes() {
  const location = useLocation();
  
  return (
    <PageTransition type="fade">
      <main id="main-content" tabIndex={-1}>
        <Routes location={location} key={location.pathname}>
          <Route path="/" element={<Dashboard />} />
          <Route path="/dashboard-old" element={<DashboardPage />} />
          <Route path="/devices" element={<DevicesPage />} />
          <Route path="/devices/:deviceId" element={<DeviceDetail />} />
          <Route path="/commands" element={<CommandsPage />} />
          <Route path="/analytics" element={<AnalyticsPage />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/notifications" element={<NotificationDemo />} />
          <Route path="/animations" element={<AnimationsDemo />} />
          <Route path="/advanced-demo" element={<AdvancedDemo />} />
        </Routes>
      </main>
    </PageTransition>
  );
}

function App() {
  return (
    <ErrorBoundary>
      <BrowserRouter>
        <SkipLink />
        <MainLayout>
          <AppRoutes />
        </MainLayout>
      </BrowserRouter>
    </ErrorBoundary>
  );
}

export default App;


