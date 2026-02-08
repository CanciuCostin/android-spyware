import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Grid,
  IconButton,
  TextField,
  Tooltip,
  Typography,
  Tab,
  Tabs,
  Alert,
  CircularProgress
} from '@mui/material';
import {
  Refresh as RefreshIcon,
  PlayArrow as LaunchIcon,
  Stop as KillIcon,
  Delete as UninstallIcon,
  Add as InstallIcon,
  Info as InfoIcon,
  Security as PermissionsIcon
} from '@mui/icons-material';
import { apiService } from '@/services/api';

interface InstalledApp {
  id: number;
  packageName: string;
  appName: string;
  versionName: string;
  versionCode: number;
  isSystemApp: boolean;
  installTime: string;
  lastUpdateTime: string;
  permissions?: string[];
}

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;
  return (
    <div hidden={value !== index} {...other}>
      {value === index && <Box sx={{ p: 3 }}>{children}</Box>}
    </div>
  );
}

export const AppControlPanel: React.FC = () => {
  const { deviceId } = useParams<{ deviceId: string }>();
  const [apps, setApps] = useState<InstalledApp[]>([]);
  const [loading, setLoading] = useState(false);
  const [tabValue, setTabValue] = useState(0);
  const [searchQuery, setSearchQuery] = useState('');
  const [installDialogOpen, setInstallDialogOpen] = useState(false);
  const [apkUrl, setApkUrl] = useState('');
  const [notification, setNotification] = useState<{ type: 'success' | 'error' | 'info'; message: string } | null>(null);

  useEffect(() => {
    loadApps();
  }, [deviceId]);

  const loadApps = async () => {
    setLoading(true);
    try {
      const response = await apiService.get(`/devices/${deviceId}/apps`);
      setApps(response.data);
    } catch (error) {
      showNotification('error', 'Failed to load apps');
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = async () => {
    try {
      await apiService.post(`/devices/${deviceId}/apps/refresh`);
      showNotification('info', 'Refreshing app list...');
      setTimeout(loadApps, 3000);
    } catch (error) {
      showNotification('error', 'Failed to refresh apps');
    }
  };

  const handleInstall = async () => {
    if (!apkUrl) {
      showNotification('error', 'Please enter APK URL');
      return;
    }

    try {
      await apiService.post(`/devices/${deviceId}/apps/install`, { apk_url: apkUrl });
      showNotification('success', 'App installation started');
      setInstallDialogOpen(false);
      setApkUrl('');
    } catch (error) {
      showNotification('error', 'Failed to install app');
    }
  };

  const handleUninstall = async (app: InstalledApp) => {
    if (!confirm(`Uninstall ${app.appName}?`)) return;

    try {
      await apiService.delete(`/devices/${deviceId}/apps/${app.packageName}`);
      showNotification('success', 'App uninstallation started');
      setTimeout(loadApps, 2000);
    } catch (error) {
      showNotification('error', 'Failed to uninstall app');
    }
  };

  const handleLaunch = async (app: InstalledApp) => {
    try {
      await apiService.post(`/devices/${deviceId}/apps/${app.packageName}/launch`);
      showNotification('success', `Launching ${app.appName}`);
    } catch (error) {
      showNotification('error', 'Failed to launch app');
    }
  };

  const handleKill = async (app: InstalledApp) => {
    try {
      await apiService.post(`/devices/${deviceId}/apps/${app.packageName}/kill`);
      showNotification('success', `Killed ${app.appName}`);
    } catch (error) {
      showNotification('error', 'Failed to kill app');
    }
  };

  const showNotification = (type: 'success' | 'error' | 'info', message: string) => {
    setNotification({ type, message });
    setTimeout(() => setNotification(null), 5000);
  };

  const filteredApps = apps.filter(app => {
    const matchesSearch = 
      app.appName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      app.packageName.toLowerCase().includes(searchQuery.toLowerCase());
    
    if (tabValue === 0) return matchesSearch;
    if (tabValue === 1) return matchesSearch && !app.isSystemApp;
    if (tabValue === 2) return matchesSearch && app.isSystemApp;
    return matchesSearch;
  });

  const renderAppCard = (app: InstalledApp) => (
    <Card key={app.id} sx={{ mb: 2 }}>
      <CardContent>
        <Grid container spacing={2} alignItems="center">
          <Grid item xs={12} md={6}>
            <Typography variant="h6">{app.appName}</Typography>
            <Typography variant="body2" color="textSecondary">
              {app.packageName}
            </Typography>
            <Typography variant="caption" display="block">
              Version: {app.versionName} ({app.versionCode})
            </Typography>
            <Box sx={{ mt: 1 }}>
              <Chip
                label={app.isSystemApp ? 'System' : 'User'}
                size="small"
                color={app.isSystemApp ? 'default' : 'primary'}
                sx={{ mr: 1 }}
              />
            </Box>
          </Grid>
          
          <Grid item xs={12} md={6}>
            <Box sx={{ display: 'flex', gap: 1, justifyContent: 'flex-end', flexWrap: 'wrap' }}>
              <Tooltip title="Launch">
                <IconButton onClick={() => handleLaunch(app)} color="primary">
                  <LaunchIcon />
                </IconButton>
              </Tooltip>
              
              <Tooltip title="Kill Process">
                <IconButton onClick={() => handleKill(app)} color="warning">
                  <KillIcon />
                </IconButton>
              </Tooltip>
              
              {!app.isSystemApp && (
                <Tooltip title="Uninstall">
                  <IconButton onClick={() => handleUninstall(app)} color="error">
                    <UninstallIcon />
                  </IconButton>
                </Tooltip>
              )}
              
              <Tooltip title="Permissions">
                <IconButton color="info">
                  <PermissionsIcon />
                </IconButton>
              </Tooltip>
            </Box>
          </Grid>
        </Grid>
      </CardContent>
    </Card>
  );

  return (
    <Box sx={{ p: 3 }}>
      {notification && (
        <Alert severity={notification.type} sx={{ mb: 2 }} onClose={() => setNotification(null)}>
          {notification.message}
        </Alert>
      )}

      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4">App Control Panel</Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Button
            variant="contained"
            startIcon={<InstallIcon />}
            onClick={() => setInstallDialogOpen(true)}
          >
            Install App
          </Button>
          <Button
            variant="outlined"
            startIcon={<RefreshIcon />}
            onClick={handleRefresh}
            disabled={loading}
          >
            Refresh
          </Button>
        </Box>
      </Box>

      <TextField
        fullWidth
        placeholder="Search apps..."
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        sx={{ mb: 2 }}
      />

      <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 2 }}>
        <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)}>
          <Tab label={`All Apps (${apps.length})`} />
          <Tab label={`User Apps (${apps.filter(a => !a.isSystemApp).length})`} />
          <Tab label={`System Apps (${apps.filter(a => a.isSystemApp).length})`} />
        </Tabs>
      </Box>

      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
          <CircularProgress />
        </Box>
      ) : (
        <>
          <TabPanel value={tabValue} index={0}>
            {filteredApps.map(renderAppCard)}
          </TabPanel>
          <TabPanel value={tabValue} index={1}>
            {filteredApps.map(renderAppCard)}
          </TabPanel>
          <TabPanel value={tabValue} index={2}>
            {filteredApps.map(renderAppCard)}
          </TabPanel>
        </>
      )}

      <Dialog open={installDialogOpen} onClose={() => setInstallDialogOpen(false)}>
        <DialogTitle>Install App</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="APK URL"
            value={apkUrl}
            onChange={(e) => setApkUrl(e.target.value)}
            placeholder="https://example.com/app.apk"
            sx={{ mt: 2 }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setInstallDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleInstall} variant="contained">Install</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};
