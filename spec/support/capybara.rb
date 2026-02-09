# frozen_string_literal: true

require 'capybara/rspec'
require 'selenium-webdriver'

# Configure headless Chrome for system tests
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-gpu')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1440,900')
  options.add_argument('--disable-extensions')
  options.add_argument('--disable-popup-blocking')

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options
  )
end

Capybara.javascript_driver = :headless_chrome
Capybara.default_driver = :headless_chrome

Capybara.configure do |config|
  config.default_max_wait_time = 10
  config.server = :puma, { Silent: true }
  config.raise_server_errors = true
  config.automatic_label_click = true
end

# Screenshot directory for failure artifacts
SCREENSHOT_DIR = Rails.root.join('tmp', 'screenshots')
FileUtils.mkdir_p(SCREENSHOT_DIR) unless File.directory?(SCREENSHOT_DIR)

Capybara.save_path = SCREENSHOT_DIR

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_chrome
  end

  # Save screenshot on failure for CI debugging
  config.after(:each, type: :system) do |example|
    if example.exception
      timestamp = Time.now.utc.strftime('%Y%m%d_%H%M%S')
      slug = example.full_description.parameterize(separator: '_')[0..80]
      filename = "#{timestamp}_#{slug}.png"
      page.save_screenshot(File.join(SCREENSHOT_DIR, filename))
    end
  end
end
