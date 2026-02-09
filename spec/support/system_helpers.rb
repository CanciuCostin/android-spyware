# frozen_string_literal: true

# Shared helpers for system (browser) tests.
module SystemHelpers
  ADMIN_EMAIL = 'admin@example.com'
  ADMIN_PASSWORD = 'password123456'

  # ------------------------------------------------------------------
  # Authentication
  # ------------------------------------------------------------------

  # Sign in via the Devise login form used by ActiveAdmin.
  def admin_login(email: ADMIN_EMAIL, password: ADMIN_PASSWORD)
    user = AdminUser.find_or_create_by!(email: email) do |u|
      u.password = password
      u.password_confirmation = password
    end
    visit new_admin_user_session_path
    fill_in 'admin_user_email', with: email
    fill_in 'admin_user_password', with: password
    click_button 'Login'
    expect(page).to have_css('#header', wait: 10)
    user
  end

  # ------------------------------------------------------------------
  # AJAX / Turbolinks helpers
  # ------------------------------------------------------------------

  # Wait until all jQuery AJAX requests have completed.
  def wait_for_ajax(timeout: Capybara.default_max_wait_time)
    Timeout.timeout(timeout) do
      loop until finished_all_ajax?
    end
  end

  # Wait for Turbolinks navigation to settle.
  def wait_for_turbolinks(timeout: Capybara.default_max_wait_time)
    Timeout.timeout(timeout) do
      loop until page.evaluate_script('typeof Turbolinks === "undefined" || !Turbolinks.controller.adapter.progressBar.visible')
    end
  rescue Timeout::Error
    # Turbolinks may not be loaded on every page — safe to ignore.
  end

  # ------------------------------------------------------------------
  # JavaScript error detection
  # ------------------------------------------------------------------

  # Collect JS console errors captured during the test.
  def javascript_errors
    page.driver.browser.logs.get(:browser).select { |e| e.level == 'SEVERE' }
  rescue Selenium::WebDriver::Error::UnknownError
    [] # Some drivers don't support log retrieval
  end

  def expect_no_javascript_errors
    errors = javascript_errors
    expect(errors).to be_empty, "Expected no JS errors, got:\n#{errors.map(&:message).join("\n")}"
  end

  # ------------------------------------------------------------------
  # UI interaction helpers
  # ------------------------------------------------------------------

  # Click a tab button by its visible text.
  def click_tab(label)
    find('.tab-btn', text: label).click
    wait_for_ajax
  end

  # Select value from a dropdown by its CSS id.
  def select_from_dropdown(id, value)
    find("##{id}").find("option[value='#{value}']").select_option
  end

  # ------------------------------------------------------------------
  # Data helpers (deterministic)
  # ------------------------------------------------------------------

  # Create an installed device ready for the dashboard.
  def create_installed_device(name: 'Test Device', device_id: 'test-device-e2e')
    payload = ApkPayload.find_or_create_by!(name: 'e2e-payload') do |p|
      p.destination_ip = '127.0.0.1'
      p.destination_port = '8080'
      p.forwarding_ip = '127.0.0.1'
      p.forwarding_port = '8080'
    end

    installation = ApkInstallation.find_or_create_by!(target_ip: device_id) do |i|
      i.apk_payload = payload
      i.status = 'installed'
    end

    Smartphone.find_or_create_by!(device_id: device_id) do |s|
      s.apk_installation = installation
      s.name = name
      s.operating_system = 'Android 13'
      s.is_rooted = 'false'
      s.is_app_hidden = 'false'
    end
  end

  private

  def finished_all_ajax?
    page.evaluate_script('typeof jQuery === "undefined" || jQuery.active === 0')
  rescue Selenium::WebDriver::Error::JavascriptError
    true
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
  config.include ActiveSupport::Testing::TimeHelpers, type: :system

  config.before(:each, type: :system) do
    # Stub services that require external dependencies
    allow(AuditService).to receive(:log).and_return(nil) if defined?(AuditService)
    allow(AlertService).to receive(:trigger).and_return([]) if defined?(AlertService)

    # Stub Redis if present
    if defined?(RedisPool)
      redis_double = double('redis')
      allow(redis_double).to receive_messages(
        sadd: true, srem: true, set: 'OK',
        sismember: false, smembers: [], get: nil, del: true
      )
      allow(RedisPool).to receive(:with).and_yield(redis_double)
    end

    # Stub background jobs
    if defined?(TimeoutCommandJob)
      allow(TimeoutCommandJob).to receive_message_chain(:set, :perform_later)
    end
  end
end
