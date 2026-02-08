# Testing Documentation for README.md

Add this section to the main README.md file:

---

## Testing

EagleSpy V5 has a comprehensive test suite with 100+ test cases covering critical components.

### Quick Start

```bash
# Install dependencies
bundle install

# Prepare test database
bundle exec rails db:test:prepare

# Run all tests
bundle exec rspec

# Run specific test suite
bundle exec rspec spec/channels/connection_spec.rb
```

### Test Coverage

The test suite covers:

- **Connection Authentication** (11 tests)
  - Device token validation
  - Admin session authentication
  - Auto-device creation
  - Race condition handling

- **File Transfers** (19 tests)
  - Chunked upload/download
  - Chunk reassembly
  - Concurrent uploads
  - Error handling

- **Command Sending** (17 tests)
  - Command validation
  - Parameter sanitization
  - ActionCable broadcasting
  - Timeout handling

- **Device Commands** (23 tests)
  - Command execution
  - Device validation
  - Result pattern
  - Class methods

- **Response Processors** (39 tests)
  - Location data processing
  - Contacts parsing
  - Device info extraction
  - Error handling

### Running Tests

```bash
# All tests
.\run_tests.ps1 all          # Windows
./run_tests.sh all           # Linux/Mac

# Specific test suite
.\run_tests.ps1 connection   # Connection tests
.\run_tests.ps1 commands     # Command tests
.\run_tests.ps1 processors   # Processor tests

# With coverage report
.\run_tests.ps1 coverage

# Help
.\run_tests.ps1 help
```

### Documentation

- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Comprehensive testing guide
- **[TEST_SUITE_SUMMARY.md](TEST_SUITE_SUMMARY.md)** - Test suite overview
- **Coverage Target**: >80% overall, >95% for critical paths

### Test Structure

```
spec/
├── channels/          # ActionCable connection tests
├── controllers/       # Controller and concern tests
├── services/          # Service object tests
│   └── response_processors/  # Response processor tests
├── factories/         # FactoryBot test data
└── support/          # Test helpers
```

### Writing Tests

Follow RSpec best practices:

```ruby
RSpec.describe MyService do
  let(:device) { create(:smartphone) }
  
  describe '#process' do
    context 'with valid input' do
      it 'processes successfully' do
        result = MyService.new(device).process
        expect(result).to be_success
      end
    end
    
    context 'with invalid input' do
      it 'returns an error' do
        result = MyService.new(nil).process
        expect(result).to be_failure
      end
    end
  end
end
```

See [TESTING_GUIDE.md](TESTING_GUIDE.md) for detailed information.

---
