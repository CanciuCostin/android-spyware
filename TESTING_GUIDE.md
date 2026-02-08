# EagleSpy V5 Testing Guide

This guide provides comprehensive information about testing the EagleSpy V5 application.

## Table of Contents

1. [Overview](#overview)
2. [Running Tests](#running-tests)
3. [Test Structure](#test-structure)
4. [Writing New Tests](#writing-new-tests)
5. [Test Coverage](#test-coverage)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

## Overview

EagleSpy V5 uses **RSpec** as its testing framework with the following tools:

- **RSpec Rails** - Rails integration for RSpec
- **FactoryBot** - Test data generation
- **SimpleCov** - Code coverage analysis
- **WebMock** - HTTP request mocking
- **Database Cleaner** - Transaction management

### Test Structure

```
spec/
├── channels/               # ActionCable connection tests
│   └── connection_spec.rb
├── controllers/            # Controller tests
│   ├── concerns/
│   │   └── command_sender_spec.rb
│   └── file_transfers_controller_spec.rb
├── factories/              # FactoryBot factories
│   ├── apk_installations.rb
│   ├── apk_payloads.rb
│   ├── pending_commands.rb
│   └── smartphones.rb
├── models/                 # Model tests
├── services/               # Service object tests
│   ├── device_command_service_spec.rb
│   └── response_processors/
│       ├── contacts_response_processor_spec.rb
│       ├── device_info_response_processor_spec.rb
│       └── location_response_processor_spec.rb
├── support/                # Test helpers
│   ├── factory_bot.rb
│   └── webmock.rb
├── rails_helper.rb         # Rails test configuration
└── spec_helper.rb          # RSpec configuration
```

## Running Tests

### Run All Tests

```bash
bundle exec rspec
```

### Run Specific Test File

```bash
bundle exec rspec spec/services/device_command_service_spec.rb
```

### Run Tests by Pattern

```bash
# Run all controller tests
bundle exec rspec spec/controllers

# Run all response processor tests
bundle exec rspec spec/services/response_processors

# Run tests matching a pattern
bundle exec rspec spec --pattern "**/*_processor_spec.rb"
```

### Run Specific Examples

```bash
# Run tests matching a description
bundle exec rspec spec/services/device_command_service_spec.rb -e "creates PendingCommand"

# Run tests by line number
bundle exec rspec spec/services/device_command_service_spec.rb:42
```

### Run with Coverage Report

```bash
# Coverage is enabled by default in rails_helper.rb
bundle exec rspec

# View coverage report
open coverage/index.html   # macOS
xdg-open coverage/index.html  # Linux
start coverage\index.html  # Windows
```

### Run with Different Formatters

```bash
# Documentation format (detailed)
bundle exec rspec --format documentation

# Progress format (dots)
bundle exec rspec --format progress

# HTML report
bundle exec rspec --format html --out rspec_results.html
```

## Test Structure

### Describe, Context, and It Blocks

```ruby
RSpec.describe MyService do
  # Describe the method or functionality
  describe '#process' do
    # Context defines the scenario
    context 'with valid input' do
      # It defines the expected outcome
      it 'processes successfully' do
        # Test code here
        expect(result).to be_success
      end
    end
    
    context 'with invalid input' do
      it 'returns an error' do
        expect(result).to be_failure
      end
    end
  end
end
```

### Using let() for Test Data

```ruby
RSpec.describe LocationResponseProcessor do
  # let() is lazily evaluated
  let(:smartphone) { create(:smartphone) }
  let(:pending_command) { create(:pending_command, smartphone: smartphone) }
  let(:response) { { 'location' => { 'latitude' => 40.0, 'longitude' => -74.0 } } }
  
  # let!() is evaluated immediately
  let!(:existing_location) { create(:geo_location, smartphone: smartphone) }
  
  describe '#process' do
    it 'creates a new location' do
      processor = LocationResponseProcessor.new(pending_command, response)
      expect { processor.process }.to change(GeoLocation, :count).by(1)
    end
  end
end
```

### Setup and Teardown

```ruby
RSpec.describe FileTransfersController do
  before(:each) do
    # Runs before each test
    ENV['DEVICE_AUTH_TOKEN'] = 'test-token'
    FileUtils.mkdir_p(Rails.root.join('tmp', 'uploads'))
  end
  
  after(:each) do
    # Runs after each test
    ENV.delete('DEVICE_AUTH_TOKEN')
    FileUtils.rm_rf(Rails.root.join('tmp', 'uploads'))
  end
  
  before(:all) do
    # Runs once before all tests in this block
  end
  
  after(:all) do
    # Runs once after all tests in this block
  end
end
```

## Writing New Tests

### 1. Create a Test File

Test files should match the name of the class being tested with `_spec.rb` suffix:

```
app/services/my_service.rb → spec/services/my_service_spec.rb
app/controllers/my_controller.rb → spec/controllers/my_controller_spec.rb
```

### 2. Use FactoryBot for Test Data

Define factories in `spec/factories/`:

```ruby
# spec/factories/smartphones.rb
FactoryBot.define do
  factory :smartphone do
    association :apk_installation
    name { "Test Phone" }
    device_id { "device-#{SecureRandom.hex(4)}" }
    operating_system { "Android 11" }
    is_rooted { false }
    
    trait :rooted do
      is_rooted { true }
    end
  end
end
```

Use in tests:

```ruby
let(:smartphone) { create(:smartphone) }
let(:rooted_smartphone) { create(:smartphone, :rooted) }
let(:custom_smartphone) { create(:smartphone, name: 'Custom Name') }
```

### 3. Test Both Success and Failure Cases

```ruby
describe '#upload_chunk' do
  context 'with valid parameters' do
    it 'uploads successfully' do
      # Test success case
      expect(response).to have_http_status(:ok)
    end
  end
  
  context 'with invalid parameters' do
    it 'returns an error' do
      # Test failure case
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
  
  context 'with missing authentication' do
    it 'rejects the request' do
      # Test security case
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

### 4. Test Edge Cases

```ruby
describe LocationResponseProcessor do
  it 'handles zero coordinates' do
    response = { 'location' => { 'latitude' => 0.0, 'longitude' => 0.0 } }
    # Test edge case
  end
  
  it 'handles extreme coordinates' do
    response = { 'location' => { 'latitude' => 90.0, 'longitude' => 180.0 } }
    # Test boundary
  end
  
  it 'handles nil values' do
    response = { 'location' => { 'latitude' => nil, 'longitude' => nil } }
    # Test null case
  end
end
```

### 5. Mock External Dependencies

```ruby
describe DeviceCommandService do
  it 'broadcasts command via ActionCable' do
    expect(ActionCable.server).to receive(:broadcast).with(
      "commands_#{device.device_id}",
      hash_including(command: 'get_location')
    )
    
    service.call
  end
  
  it 'handles file system errors' do
    allow(File).to receive(:write).and_raise(Errno::EACCES)
    
    expect { processor.process }.to raise_error(Errno::EACCES)
  end
end
```

## Test Coverage

### Critical Components Tested

1. **Connection Authentication** (`spec/channels/connection_spec.rb`)
   - ✅ Valid device token authentication
   - ✅ Invalid token rejection
   - ✅ Missing token handling
   - ✅ Token from query params vs headers
   - ✅ Auto-device creation
   - ✅ Race condition handling

2. **File Transfers** (`spec/controllers/file_transfers_controller_spec.rb`)
   - ✅ Single and multiple chunk uploads
   - ✅ Chunk reassembly
   - ✅ Out-of-order chunk handling
   - ✅ Invalid chunk rejection
   - ✅ Concurrent uploads
   - ✅ File finalization
   - ✅ Missing chunks detection

3. **Response Processors** (`spec/services/response_processors/`)
   - ✅ LocationResponseProcessor - coordinate validation
   - ✅ ContactsResponseProcessor - contact parsing
   - ✅ DeviceInfoResponseProcessor - device data extraction
   - ✅ Error handling in all processors

4. **Command Sending** (`spec/controllers/concerns/command_sender_spec.rb`)
   - ✅ PendingCommand creation
   - ✅ ActionCable broadcast
   - ✅ Request ID generation
   - ✅ Parameter sanitization
   - ✅ Command whitelist validation
   - ✅ wait_for_response timeout

5. **Device Commands** (`spec/services/device_command_service_spec.rb`)
   - ✅ Command validation
   - ✅ Device validation
   - ✅ Result pattern implementation
   - ✅ Legacy method compatibility
   - ✅ Class methods (devices_snapshot, command_queue, etc.)

### Coverage Goals

- **Minimum Coverage**: 80% overall
- **Critical Paths**: 95%+ coverage
- **Security Code**: 100% coverage (authentication, sanitization)

View current coverage:

```bash
bundle exec rspec
open coverage/index.html
```

## Best Practices

### DO's

✅ **Use `let()` for test data**
```ruby
let(:smartphone) { create(:smartphone) }
```

✅ **Use descriptive test names**
```ruby
it 'marks command as failed when latitude is missing'
```

✅ **Test one thing per example**
```ruby
it 'creates a GeoLocation record' do
  expect { processor.process }.to change(GeoLocation, :count).by(1)
end
```

✅ **Clean up test data**
```ruby
after { FileUtils.rm_rf(test_directory) }
```

✅ **Use factories over fixtures**
```ruby
let(:smartphone) { create(:smartphone) }  # Good
let(:smartphone) { smartphones(:one) }    # Avoid
```

✅ **Test error paths**
```ruby
context 'when database is down' do
  it 'handles the error gracefully' do
    allow(GeoLocation).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
    expect { processor.process }.not_to raise_error
  end
end
```

### DON'Ts

❌ **Don't use instance variables**
```ruby
before { @smartphone = create(:smartphone) }  # Bad
let(:smartphone) { create(:smartphone) }       # Good
```

❌ **Don't test implementation details**
```ruby
# Bad - tests internal method
expect(service).to receive(:validate_params)

# Good - tests outcome
expect(service.call).to be_success
```

❌ **Don't use `sleep` for timing**
```ruby
sleep 1  # Bad
Timecop.freeze(Time.now + 1.second)  # Good (with timecop gem)
```

❌ **Don't share state between tests**
```ruby
# Bad - modifies global state
before(:all) { @shared = create(:smartphone) }

# Good - each test is independent
let(:smartphone) { create(:smartphone) }
```

❌ **Don't mock what you don't own**
```ruby
# Bad - mocking Rails framework
allow(ActiveRecord::Base).to receive(:transaction)

# Good - test the behavior
expect { service.call }.to change(Smartphone, :count)
```

## Troubleshooting

### Tests Failing with Database Errors

```bash
# Reset test database
RAILS_ENV=test bundle exec rails db:reset

# Run migrations
RAILS_ENV=test bundle exec rails db:migrate
```

### FactoryBot Errors

```bash
# Check factory definitions are valid
bundle exec rails factory_bot:lint
```

### Random Test Failures

```bash
# Run tests in random order to detect dependencies
bundle exec rspec --order random

# Run with a specific seed to reproduce
bundle exec rspec --seed 12345
```

### Slow Tests

```bash
# Profile slowest tests
bundle exec rspec --profile 10

# Run only fast tests
bundle exec rspec --tag ~slow
```

### Coverage Not Generated

Check `spec/rails_helper.rb` has SimpleCov enabled:

```ruby
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
end
```

### ActionCable Connection Tests Failing

Ensure you have the connection test helper:

```ruby
# spec/support/action_cable.rb
RSpec.configure do |config|
  config.include ActionCable::TestHelper, type: :channel
end
```

## Continuous Integration

### GitHub Actions

Create `.github/workflows/test.yml`:

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 2.6.6
          bundler-cache: true
      
      - name: Setup Database
        env:
          RAILS_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
        run: |
          bundle exec rails db:setup
      
      - name: Run Tests
        env:
          RAILS_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
        run: bundle exec rspec
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v2
        with:
          files: ./coverage/.resultset.json
```

## Additional Resources

- [RSpec Documentation](https://rspec.info/)
- [FactoryBot Documentation](https://github.com/thoughtbot/factory_bot)
- [Better Specs](https://www.betterspecs.org/)
- [Thoughtbot Testing Guide](https://thoughtbot.com/blog/tags/testing)

## Getting Help

If you encounter issues:

1. Check this guide
2. Review existing tests for patterns
3. Run `bundle exec rspec --help` for options
4. Check RSpec and FactoryBot documentation
5. Ask the team for code review

---

**Last Updated**: February 2026  
**Maintainer**: EagleSpy V5 Team
