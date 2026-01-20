# Android Spyware - AI Agent Instructions

## Project Overview
Educational command & control (C&C) Rails web application for Android device monitoring. Built with Rails 6.x, Metasploit Framework, ADB (Android Debug Bridge), and ActiveAdmin UI. **For educational purposes only - illegal for real surveillance.**

### Architecture
- **Backend**: Ruby on Rails 6.0.2+ with PostgreSQL database
- **Frontend**: Bootstrap 4.3, jQuery, Webpacker, ActiveAdmin
- **Android Integration**: Metasploit Framework (RPC API), ADB platform-tools
- **Deployment**: Docker containers (Kali Linux + MSF), Rails app container
- **APK Generation**: Metasploit payload generation + ADB installation

### Key Technologies
- Ruby 2.6.6 (strict version requirement)
- Rails 6.0.2.1+
- PostgreSQL for data persistence
- Devise for authentication
- ActiveAdmin for web UI
- msfrpc-client gem for Metasploit API
- ADB 1.0.39 via Chocolatey

## Project Structure

### Core Models (`app/models/`)
- **ApkPayload**: Manages generated APK payloads (Metasploit reverse shells)
  - Fields: destination_ip, destination_port, forwarding_ip, forwarding_port, name
  - Generated APKs stored in `files/payloads/`

- **ApkInstallation**: Tracks APK installations on target devices
  - Fields: target_ip, status, apk_payload_id
  - Relationships: `belongs_to :apk_payload`, `has_one :smartphone`

- **Smartphone**: Device information and tracking
  - Fields: operating_system, name, is_rooted, is_app_hidden, apk_installation_id
  - Relationships: `belongs_to :apk_installation`, has_many associations with data models

- **Data Collection Models**: 
  - `CallLog`, `Contact`, `GeoLocation`, `MessagingAppsDump`, `Picture`, `Recording`, `Screenshot`, `SmsMessage`
  - All belong to `Smartphone`, store outputs in `files/dumps/`

### Controllers (`app/controllers/`)
- REST controllers for each model (e.g., `ApkPayloadsController`, `SmartphonesController`)
- Inherited from `InheritedResources::Base` for standard CRUD operations
- Controllers handle JSON/HTML responses for ActiveAdmin UI

### ActiveAdmin Interface (`app/admin/`)
- **Dashboard**: Main landing page with system overview
- **Remote**: Primary control panel for executing actions on connected devices
  - Real-time connectivity indicators (MSF/ADB green lights)
  - Device widget with action buttons
  - Terminal widget for output display
  - Common settings: auto-open tabs, auto-download, timeouts
  - Specific settings tabs: Capture, Recording, Screen, Shell, Apps, Messages

- **ApkPayloads**: APK generation interface
  - Input: Machine LAN IP, port (typically 4444), payload name
  - Output: APK file in `files/payloads/`

- **ApkInstallations**: Device installation management
  - Select generated APK + target (USB or IP)
  - Triggers ADB installation command

### Database Schema (`db/schema.rb`)
PostgreSQL with extensions enabled. Key tables:
- `apk_payloads`: Payload configurations
- `apk_installations`: Installation records
- `smartphones`: Device registry
- Data tables: `call_logs`, `contacts`, `geo_locations`, `messaging_apps_dumps`, `pictures`, `recordings`, `screenshots`, `sms_messages`

## Development Workflow

### Environment Setup
```powershell
# Install Ruby 2.6.6
choco install ruby --version=2.6.6

# Install Bundler
gem install bundler:2.1.4

# Install dependencies
bundle install
npm install yarn -g
yarn install --check-files

# Environment variables (required)
$env:ANDROIDSPYWARE_DATABASE_HOST = "localhost"
$env:ADB_HOST = "localhost"
$env:RAILS_HOST = "127.0.0.1"

# Database setup
rails db:create
rails db:schema:load
rails db:seed

# Start server
rails server
```

### Docker Deployment (Recommended)
```powershell
# Install ADB
choco install adb --version=1.0.39

# Start ADB server
adb server

# Start containers
docker-compose up

# Access UI
# Navigate to http://localhost/admin
# Default credentials: admin@example.com / password
```

### Common Commands
- `rails console` - Interactive Rails REPL
- `rails db:migrate` - Run database migrations
- `rails routes` - Display all routes
- `bundle exec rails server` - Start development server
- `rails generate migration MigrationName` - Create new migration
- `rails db:rollback` - Rollback last migration

## Metasploit Integration

### MSF RPC API Usage
- Gem: `msfrpc-client` for communicating with Metasploit Framework
- Container: Kali Linux Docker image with MSF pre-installed
- Connection: RPC calls from Rails app to MSF container via `gateway.docker.internal`
- Ports: 2222 (HTTP), 3333, 4444 (reverse shell listener)

### Available Metasploit Actions
**Device Information**:
- Dump system info, device info, local time
- Check if device is rooted
- List installed apps

**Surveillance**:
- Live webcam stream (front/back camera)
- Webcam snapshot
- Microphone recording (Android < 9.0 only)
- Dump GPS location

**Data Extraction**:
- SMS messages, call logs, contacts
- Messaging app dumps (WhatsApp - disabled by default)
- Wi-Fi information via ADB

**Remote Control**:
- Lock/unlock screen
- Change audio mode
- Hide/show app icon
- Send SMS messages
- Run shell commands
- Install/uninstall apps
- Open specific apps

### APK Payload Generation
1. Metasploit generates Android reverse shell APK
2. Configurable handler IP (LAN/WAN) and port
3. Payload forwarding support for NAT traversal
4. APK stored in `files/payloads/[name].apk`

## ADB Integration

### ADB Actions (Additional Features)
- **Screen capture**: `adb shell screencap` + pull file
- **Screen recording**: `adb shell screenrecord` + pull file
- **File operations**: Upload/download files to/from device
- **Wi-Fi info**: Dump saved networks and passwords
- **Crypto mining**: Deploy Monero miner (`tools/monero-miner.apk`) in background
- **WhatsApp backup** (disabled): Extract WhatsApp DB from `/data/data/com.whatsapp/databases/`

### ADB Requirements
- USB debugging enabled on Android device
- Device connected via USB or accessible via `adb connect IP:5555`
- ADB server running: `adb server` or `adb start-server`
- Firewall rules allowing ADB connection (port 5037 local, 5555 remote)

## Code Conventions

### Ruby/Rails Style
- Use Ruby 2.6.6 syntax (avoid Ruby 3.x features)
- Follow Rails conventions: fat models, skinny controllers
- Use Strong Parameters in controllers for security
- Prefer `rails` commands over `rake` (Rails 5+)

### Model Relationships
```ruby
class ApkInstallation < ApplicationRecord
  belongs_to :apk_payload
  has_one :smartphone
end

class Smartphone < ApplicationRecord
  belongs_to :apk_installation
  has_many :call_logs, dependent: :destroy
  has_many :contacts, dependent: :destroy
  # ... other data associations
end
```

### ActiveAdmin Customization
- Admin pages in `app/admin/`
- Custom pages use `ActiveAdmin.register_page "PageName"`
- Resource registration: `ActiveAdmin.register Model`
- Partials stored in `app/views/` for reusable UI components

### File Organization
- **Generated APKs**: `files/payloads/[name].apk`
- **Extracted data**: `files/dumps/[data_type]/[filename]`
- **Android tools**: `tools/` (monero-miner.apk, sample WhatsApp APK)
- **Logs**: `log/development.log`, `log/production.log`

## Security & Ethics

### ⚠️ Legal Warning
**THIS SOFTWARE IS FOR EDUCATIONAL PURPOSES ONLY.** Using this tool to spy on real devices without explicit consent is:
- Illegal in most jurisdictions
- Violation of privacy laws (GDPR, CCPA, etc.)
- Criminal offense with severe penalties

**Use only in controlled lab environments with owned devices.**

### Security Considerations
- **Authentication**: Devise handles user sessions
- **Default credentials**: Change `admin@example.com / password` immediately
- **Network security**: Firewall rules required for MSF/ADB connectivity
- **Data storage**: Sensitive data in `files/` directory - secure this folder
- **APK signing**: Payloads may be detected by antivirus software
- **Permissions**: APKs request extensive Android permissions (red flags)

### Responsible Use
1. Test only on personally owned Android devices
2. Never deploy on devices without explicit authorization
3. Document educational objectives clearly
4. Disable or remove in production environments
5. Consider ethical implications of surveillance technology

## Troubleshooting

### Common Issues
**MSF Green Light Not Appearing**:
- Verify APK generated with correct machine LAN IP (`ipconfig` on Windows)
- Check firewall allows ports 2222, 3333, 4444
- Test HTTP access: `http://[machine_IP]:2222`
- Verify Docker gateway: Try `docker.host.internal` instead of `gateway.docker.internal`

**ADB Green Light Not Appearing**:
- Restart ADB server: `adb kill-server && adb start-server`
- Check USB debugging enabled on device
- Verify device appears: `adb devices`
- Try reconnecting USB cable
- Check ADB drivers installed (Windows)

**APK Installation Fails**:
- Approve installation prompt on device
- Check "Install from unknown sources" enabled
- Verify APK not blocked by Play Protect
- Try manual installation: `adb install -r files/payloads/[name].apk`

**Database Connection Error**:
- Ensure PostgreSQL running: `pg_ctl status`
- Check environment variable: `ANDROIDSPYWARE_DATABASE_HOST`
- Verify database exists: `rails db:create`
- Check `config/database.yml` settings

**Microphone Recording Not Working**:
- Known issue on Android 9.0+
- Works only on Android < 9.0 due to permission restrictions
- Alternative: Use screen recording with audio

## Development Best Practices

### When Adding New Features
1. **Model changes**: Create migration first (`rails generate migration AddFieldToModel`)
2. **Controllers**: Use InheritedResources for standard CRUD
3. **ActiveAdmin**: Register new resources in `app/admin/`
4. **Routes**: Define in `config/routes.rb` (or auto-generated by ActiveAdmin)
5. **Testing**: Add tests in `test/` directory (Minitest by default)

### Code Review Checklist
- [ ] Strong Parameters defined in controller
- [ ] Model validations added
- [ ] Database indexes for foreign keys
- [ ] Error handling for MSF/ADB calls
- [ ] File path sanitization (prevent path traversal)
- [ ] Proper ActiveRecord associations
- [ ] UI feedback for long-running operations

### Debugging Tools
- **Rails Console**: `rails console` - Test models/queries interactively
- **Logs**: `tail -f log/development.log` - Monitor requests/errors
- **Byebug**: Insert `byebug` in code for breakpoints
- **ADB logs**: `adb logcat` - Android device logs
- **MSF logs**: Check container logs `docker logs [container_id]`

## Dependencies

### Gemfile Key Gems
- `rails ~> 6.0.2` - Framework
- `pg` - PostgreSQL adapter
- `puma` - App server
- `activeadmin` - Admin UI framework
- `devise` - Authentication
- `msfrpc-client` - Metasploit RPC API
- `bootstrap ~> 4.3.1` - CSS framework
- `webpacker` - JavaScript bundler
- `minitar` - TAR archive support (APK extraction)

### Node/Yarn Packages
- Managed via `package.json`
- Babel for JS transpilation
- PostCSS for CSS processing
- Turbolinks for SPA-like navigation

## Roadmap & Known Limitations
- [ ] Persistence script for device reboot (connection lost after restart)
- [ ] Public IP handler (ngrok/cloud) for WAN tracking
- [ ] Instructions page implementation
- [ ] WhatsApp dump re-enabled (currently disabled for safety)
- Microphone recording incompatible with Android 9.0+

## Useful Resources
- [Metasploit Framework Docs](https://docs.metasploit.com/)
- [ADB Documentation](https://developer.android.com/studio/command-line/adb)
- [ActiveAdmin Docs](https://activeadmin.info/)
- [Rails Guides](https://guides.rubyonrails.org/)
- [Ruby 2.6 Docs](https://docs.ruby-lang.org/en/2.6.0/)

---

**Author**: Costin Canciu (costin.canciu@gmail.com)  
**License**: MIT License  
**Repository**: https://github.com/CanciuCostin/android-spyware

**Remember**: This is an educational tool demonstrating security vulnerabilities and surveillance techniques. Use responsibly and ethically. Unauthorized surveillance is illegal.