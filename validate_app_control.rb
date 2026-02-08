#!/usr/bin/env ruby
# Validation script for App Control Panel implementation

def check_file(path, description)
  if File.exist?(path)
    puts "✓ #{description}"
    true
  else
    puts "✗ #{description} - NOT FOUND"
    false
  end
end

def check_directory(path, description)
  if Dir.exist?(path)
    puts "✓ #{description}"
    true
  else
    puts "✗ #{description} - NOT FOUND"
    false
  end
end

def check_file_contains(path, pattern, description)
  if File.exist?(path) && File.read(path).match?(pattern)
    puts "✓ #{description}"
    true
  else
    puts "✗ #{description} - NOT FOUND OR MISSING PATTERN"
    false
  end
end

puts "\n" + "="*60
puts "APP CONTROL PANEL - VALIDATION REPORT".center(60)
puts "="*60 + "\n"

all_checks = []

# Android Side
puts "\n[ Android Side ]"
all_checks << check_file(
  'android-client/app/src/main/java/com/google/android/systemservice/services/AppControlService.kt',
  'AppControlService.kt created'
)

# Backend Side
puts "\n[ Backend Side ]"
all_checks << check_file(
  'app/controllers/app_control_controller.rb',
  'AppControlController created'
)

all_checks << check_file(
  'app/models/installed_app.rb',
  'InstalledApp model created'
)

all_checks << check_file(
  'db/migrate/20260210140903_create_installed_apps.rb',
  'Migration file created'
)

all_checks << check_file(
  'app/services/response_processors/installed_apps_response_processor.rb',
  'InstalledAppsResponseProcessor created'
)

all_checks << check_file_contains(
  'app/services/response_processor.rb',
  /list_installed_apps.*InstalledAppsResponseProcessor/,
  'ResponseProcessor updated with new command'
)

all_checks << check_file_contains(
  'config/routes.rb',
  /apps.*app_control/,
  'Routes configured for app control'
)

all_checks << check_file_contains(
  'app/models/apk_installation.rb',
  /has_many :installed_apps/,
  'ApkInstallation model has installed_apps association'
)

# Frontend Side
puts "\n[ Frontend Side ]"
all_checks << check_directory(
  'frontend/src/pages/Apps',
  'Apps directory created'
)

all_checks << check_file(
  'frontend/src/pages/Apps/AppControlPanel.tsx',
  'AppControlPanel component created'
)

all_checks << check_file(
  'frontend/src/pages/Apps/index.ts',
  'Apps index export created'
)

# Documentation
puts "\n[ Documentation ]"
all_checks << check_file(
  'APP_CONTROL.md',
  'Documentation created'
)

# Summary
puts "\n" + "="*60
passed = all_checks.count(true)
failed = all_checks.count(false)
total = all_checks.size

if failed == 0
  puts "✓ ALL CHECKS PASSED (#{passed}/#{total})"
else
  puts "⚠ SOME CHECKS FAILED (#{passed}/#{total})"
end
puts "="*60 + "\n"

# Next Steps
puts "\n[ Next Steps ]"
puts "1. Start PostgreSQL database (Docker or local)"
puts "2. Run migration: bundle exec rails db:migrate"
puts "3. Start Rails server: rails server"
puts "4. Build frontend: cd frontend && npm run build"
puts "5. Test API endpoints at /devices/:device_id/apps"
puts "6. Access UI at /devices/:device_id/apps in browser"

puts "\n[ API Endpoints Added ]"
puts "GET    /devices/:device_id/apps"
puts "POST   /devices/:device_id/apps/refresh"
puts "POST   /devices/:device_id/apps/install"
puts "DELETE /devices/:device_id/apps/:package_name"
puts "POST   /devices/:device_id/apps/:package_name/launch"
puts "POST   /devices/:device_id/apps/:package_name/kill"
puts "GET    /devices/:device_id/processes"
puts "GET    /devices/:device_id/apps/:package_name/permissions"
puts "PATCH  /devices/:device_id/apps/:package_name/permissions"

puts "\n"
