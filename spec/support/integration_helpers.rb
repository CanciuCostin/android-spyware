# frozen_string_literal: true

# Common helpers shared across all integration tests.
module IntegrationHelpers
  def stub_audit_service
    allow(AuditService).to receive(:log).and_return(nil)
  end

  def stub_alert_service
    allow(AlertService).to receive(:trigger).and_return([])
  end

  def create_admin_user(email: 'admin@test.com', password: 'password123456')
    AdminUser.find_or_create_by!(email: email) do |user|
      user.password = password
      user.password_confirmation = password
    end
  end

  def freeze_test_time(time = Time.utc(2025, 1, 15, 12, 0, 0))
    travel_to(time) { yield }
  end

  def cleanup_upload_files
    upload_dir = File.join(Rails.root, 'tmp', 'uploads')
    FileUtils.rm_rf(Dir.glob("#{upload_dir}/test-*"))

    dest_dir = File.join(Rails.root, 'files', 'uploads')
    FileUtils.rm_rf(Dir.glob("#{dest_dir}/test-*"))
  end
end

RSpec.configure do |config|
  config.include IntegrationHelpers, type: :integration
  config.include ActiveSupport::Testing::TimeHelpers, type: :integration

  config.before(:each, type: :integration) do
    stub_audit_service
    stub_alert_service
    stub_redis_device_tracking if respond_to?(:stub_redis_device_tracking)
    stub_timeout_job if respond_to?(:stub_timeout_job)
  end

  config.after(:each, type: :integration) do
    cleanup_upload_files if respond_to?(:cleanup_upload_files)
  end
end
