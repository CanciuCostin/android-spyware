#!/usr/bin/env ruby
# Consent Management Implementation Validator

puts "=" * 80
puts "CONSENT MANAGEMENT SYSTEM - IMPLEMENTATION VALIDATOR"
puts "=" * 80
puts

# Check 1: Migration file exists
puts "✓ Checking migration file..."
migration_file = Dir.glob('db/migrate/*_create_consent_management.rb').first
if migration_file
  puts "  ✅ Migration file found: #{File.basename(migration_file)}"
else
  puts "  ❌ Migration file NOT found"
  exit 1
end

# Check 2: Models exist
puts "\n✓ Checking models..."
models = ['device_consent.rb', 'terms_acceptance.rb', 'data_usage_disclosure.rb']
models.each do |model|
  path = "app/models/#{model}"
  if File.exist?(path)
    puts "  ✅ #{model} exists"
  else
    puts "  ❌ #{model} NOT found"
    exit 1
  end
end

# Check 3: Service exists
puts "\n✓ Checking service..."
if File.exist?('app/services/consent_service.rb')
  puts "  ✅ ConsentService exists"
else
  puts "  ❌ ConsentService NOT found"
  exit 1
end

# Check 4: Controller exists
puts "\n✓ Checking controller..."
if File.exist?('app/controllers/consents_controller.rb')
  puts "  ✅ ConsentsController exists"
else
  puts "  ❌ ConsentsController NOT found"
  exit 1
end

# Check 5: Middleware exists
puts "\n✓ Checking middleware..."
if File.exist?('app/middleware/consent_enforcement.rb')
  puts "  ✅ ConsentEnforcement middleware exists"
else
  puts "  ❌ ConsentEnforcement middleware NOT found"
  exit 1
end

# Check 6: Routes configured
puts "\n✓ Checking routes..."
routes_content = File.read('config/routes.rb')
if routes_content.include?('resources :consents')
  puts "  ✅ Consent routes configured"
else
  puts "  ❌ Consent routes NOT configured"
  exit 1
end

# Check 7: Middleware registered
puts "\n✓ Checking middleware registration..."
app_config = File.read('config/application.rb')
if app_config.include?('ConsentEnforcement')
  puts "  ✅ ConsentEnforcement middleware registered in application.rb"
else
  puts "  ❌ ConsentEnforcement middleware NOT registered"
  exit 1
end

# Check 8: Documentation exists
puts "\n✓ Checking documentation..."
if File.exist?('CONSENT_MANAGEMENT_GUIDE.md')
  puts "  ✅ CONSENT_MANAGEMENT_GUIDE.md exists"
  
  doc_content = File.read('CONSENT_MANAGEMENT_GUIDE.md')
  puts "  ✅ Documentation size: #{doc_content.length} bytes"
  
  # Check for key sections
  key_sections = [
    'GDPR Compliance Features',
    'API Endpoints',
    'Consent Types',
    'Database Schema',
    'Best Practices'
  ]
  
  key_sections.each do |section|
    if doc_content.include?(section)
      puts "  ✅ Section present: #{section}"
    else
      puts "  ⚠️  Section missing: #{section}"
    end
  end
else
  puts "  ❌ CONSENT_MANAGEMENT_GUIDE.md NOT found"
  exit 1
end

# Check 9: Test file exists
puts "\n✓ Checking tests..."
if File.exist?('spec/consent_management_spec.rb')
  puts "  ✅ Test file exists"
  
  test_content = File.read('spec/consent_management_spec.rb')
  test_count = test_content.scan(/\sit ['"].*['"]/).length
  puts "  ✅ Test cases defined: #{test_count}"
else
  puts "  ⚠️  Test file NOT found (optional)"
end

# Check 10: Model associations
puts "\n✓ Checking ApkInstallation associations..."
apk_model_content = File.read('app/models/apk_installation.rb')
associations = ['device_consents', 'terms_acceptances', 'data_usage_disclosures']
associations.each do |assoc|
  if apk_model_content.include?(assoc)
    puts "  ✅ Association present: #{assoc}"
  else
    puts "  ❌ Association missing: #{assoc}"
    exit 1
  end
end

# Summary
puts "\n" + "=" * 80
puts "VALIDATION SUMMARY"
puts "=" * 80

puts "\n✅ All critical components are in place!"
puts

puts "Next Steps:"
puts "1. Run migration: rails db:migrate"
puts "2. Review CONSENT_MANAGEMENT_GUIDE.md"
puts "3. Run tests: rspec spec/consent_management_spec.rb"
puts "4. Configure CONSENT_VERSION environment variable"
puts "5. Add consent text translations to config/locales/consents.yml"
puts "6. Test consent enforcement on protected endpoints"
puts "7. Review and customize consent types for your use case"
puts

puts "GDPR Compliance Checklist:"
puts "□ Update consent form text with legal review"
puts "□ Set up AdminMailer for consent revocation notifications"
puts "□ Configure audit trail exports"
puts "□ Update privacy policy to reference consent system"
puts "□ Test consent withdrawal workflow end-to-end"
puts "□ Schedule regular consent history exports"
puts

puts "=" * 80
puts "Implementation validation complete! ✅"
puts "=" * 80
