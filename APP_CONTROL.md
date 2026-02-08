# App Control Panel Documentation

## Overview

The App Control Panel enables remote management of Android applications on target devices. Admins can install/uninstall apps, launch/kill processes, monitor running applications, and manage app permissions.

## Features

### 1. App Listing & Monitoring
- List all installed applications (system and user apps)
- View app metadata (package name, version, install date)
- Filter by app type (all/user/system)
- Search apps by name or package name

### 2. App Lifecycle Management
- **Install**: Remote install APK from URL
- **Uninstall**: Remove user-installed apps
- **Launch**: Start an application
- **Kill**: Terminate app processes

### 3. Process Management
- View running processes
- Monitor app resource usage
- Kill background processes

### 4. Permission Management
- View app permissions
- Grant/revoke permissions remotely

## API Endpoints

### List Installed Apps
```
GET /devices/:device_id/apps
```
Returns all installed apps for the device.

**Response:**
```json
[
  {
    "id": 1,
    "package_name": "com.example.app",
    "app_name": "Example App",
    "version_name": "1.0.0",
    "version_code": 1,
    "is_system_app": false,
    "install_time": "2024-01-15T10:30:00Z",
    "last_update_time": "2024-01-15T10:30:00Z",
    "permissions": ["CAMERA", "LOCATION"]
  }
]
```

### Refresh App List
```
POST /devices/:device_id/apps/refresh
```
Triggers device to send updated app list.

**Response:**
```json
{
  "status": "refreshing",
  "request_id": 123
}
```

### Install App
```
POST /devices/:device_id/apps/install
```

**Request Body:**
```json
{
  "apk_url": "https://example.com/app.apk",
  "package_name": "com.example.app"
}
```

**Response:**
```json
{
  "status": "installing",
  "request_id": 124
}
```

### Uninstall App
```
DELETE /devices/:device_id/apps/:package_name
```

**Response:**
```json
{
  "status": "uninstalling",
  "request_id": 125
}
```

### Launch App
```
POST /devices/:device_id/apps/:package_name/launch
```

**Response:**
```json
{
  "status": "launching",
  "request_id": 126
}
```

### Kill App Process
```
POST /devices/:device_id/apps/:package_name/kill
```

**Response:**
```json
{
  "status": "killing",
  "request_id": 127
}
```

### List Running Processes
```
GET /devices/:device_id/processes
```

**Response:**
```json
{
  "status": "fetching",
  "request_id": 128
}
```

### Get App Permissions
```
GET /devices/:device_id/apps/:package_name/permissions
```

**Response:**
```json
{
  "permissions": [
    "android.permission.CAMERA",
    "android.permission.ACCESS_FINE_LOCATION"
  ]
}
```

### Update App Permissions
```
PATCH /devices/:device_id/apps/:package_name/permissions
```

**Request Body:**
```json
{
  "permissions": ["CAMERA", "LOCATION"],
  "grant": true
}
```

**Response:**
```json
{
  "status": "updating_permissions",
  "request_id": 129
}
```

## Android Implementation

### AppControlService

The Android side implements `AppControlService` as a Hilt Worker that handles:

- Listing installed applications using PackageManager
- Installing APKs from remote URLs
- Uninstalling applications
- Launching applications
- Killing processes via ActivityManager
- Managing permissions

### Required Permissions

The Android app requires these permissions:

```xml
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
<uses-permission android:name="android.permission.REQUEST_DELETE_PACKAGES" />
<uses-permission android:name="android.permission.KILL_BACKGROUND_PROCESSES" />
<uses-permission android:name="android.permission.INTERNET" />
```

### FileProvider Configuration

For APK installation, configure FileProvider in `AndroidManifest.xml`:

```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

Create `res/xml/file_paths.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="apk_cache" path="/" />
</paths>
```

## Backend Implementation

### Database Schema

The `installed_apps` table stores:
- Device reference
- Package name (unique per device)
- App metadata (name, version, timestamps)
- System app flag
- Permissions array (JSON)
- Custom metadata (JSON)

### Response Processor

`InstalledAppsResponseProcessor` handles device responses:
- Updates/creates app records
- Removes uninstalled apps
- Marks commands as completed/failed
- Stores response data

### Model Associations

```ruby
class ApkInstallation
  has_many :installed_apps
end

class InstalledApp
  belongs_to :device, class_name: 'ApkInstallation'
end
```

## Frontend Implementation

### AppControlPanel Component

React component with Material-UI provides:

- **Tabs**: All/User/System apps filtering
- **Search**: Real-time app search
- **App Cards**: Display app info with action buttons
- **Install Dialog**: Remote APK installation
- **Notifications**: Success/error feedback

### Usage

```tsx
import { AppControlPanel } from '@/pages/Apps/AppControlPanel';

// In router
<Route path="/devices/:deviceId/apps" element={<AppControlPanel />} />
```

### API Integration

Uses centralized `apiService` for all backend calls:

```typescript
const response = await apiService.get(`/devices/${deviceId}/apps`);
const apps = response.data;
```

## Routes Configuration

Add to `config/routes.rb`:

```ruby
resources :devices do
  scope module: 'app_control' do
    get 'apps', to: 'app_control#index'
    post 'apps/refresh', to: 'app_control#refresh'
    post 'apps/install', to: 'app_control#install'
    delete 'apps/:package_name', to: 'app_control#uninstall'
    post 'apps/:package_name/launch', to: 'app_control#launch'
    post 'apps/:package_name/kill', to: 'app_control#kill'
    get 'processes', to: 'app_control#processes'
    get 'apps/:package_name/permissions', to: 'app_control#permissions'
    patch 'apps/:package_name/permissions', to: 'app_control#update_permissions'
  end
end
```

## Database Migration

Run the migration to create the installed_apps table:

```bash
rails db:migrate
```

Or using the provided script:

```powershell
ruby execute_sql_migration.rb
```

## Security Considerations

1. **APK Installation**: Requires user interaction on Android 8.0+
2. **Permissions**: Some operations require device admin or system-level access
3. **URL Validation**: Validate APK URLs before downloading
4. **Rate Limiting**: Implement rate limiting for app operations
5. **Authorization**: Ensure proper device ownership verification

## Testing

### Manual Testing

1. Navigate to device details
2. Click "Apps" tab
3. Test operations:
   - View installed apps
   - Search apps
   - Launch an app
   - Kill a running app
   - Install app from URL (requires valid APK URL)
   - Uninstall user app

### Automated Testing

Create tests for:
- Controller endpoints
- Response processor
- Model validations
- Frontend component rendering

## Troubleshooting

### App list not updating
- Check device connectivity
- Verify pending_commands are being processed
- Check response_processor is registered

### Install fails
- Verify APK URL is accessible
- Check device has "Install from Unknown Sources" enabled
- Ensure FileProvider is configured correctly

### Permissions errors
- Verify Android app has required permissions
- Check device API level compatibility
- Some operations require root access

## Future Enhancements

- [ ] Bulk app operations
- [ ] App usage statistics
- [ ] Permission auditing and alerts
- [ ] App backup/restore
- [ ] Silent app installation (requires root)
- [ ] App data clearing
- [ ] App freezing/disabling
- [ ] Custom app categories

## Support

For issues or questions:
1. Check logs: `log/production.log`
2. Verify device connection status
3. Review pending_commands table
4. Check Android logcat output
