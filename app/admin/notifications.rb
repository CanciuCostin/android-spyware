ActiveAdmin.register_page "Notifications" do
  menu priority: 9, label: "📬 Notifications"

  content title: "📬 Device Notifications" do
    devices = DeviceNotification.select(:device_id).distinct.pluck(:device_id)
    current_device = params[:device_id] || devices.first
    current_app = params[:app_filter]
    messaging_only = params[:messaging_only] == 'true'

    # Device & Filter Selection
    div class: "notifications-header" do
      panel "Filters" do
        form action: admin_notifications_path, method: :get do
          div class: "filter-row", style: "display: flex; gap: 20px; align-items: center; flex-wrap: wrap;" do
            # Device selector
            div do
              label "Device:", style: "margin-right: 10px;"
              select name: "device_id", onchange: "this.form.submit()" do
                devices.each do |device_id|
                  option device_id, value: device_id, selected: device_id == current_device
                end
              end
            end

            # App filter
            if current_device.present?
              apps = DeviceNotification.by_device(current_device)
                                        .select(:package_name, :app_name)
                                        .distinct
                                        .pluck(:package_name, :app_name)
              div do
                label "App:", style: "margin-right: 10px;"
                select name: "app_filter", onchange: "this.form.submit()" do
                  option "All Apps", value: ""
                  apps.each do |pkg, name|
                    display = name.present? ? "#{name} (#{pkg})" : pkg
                    option display, value: pkg, selected: pkg == current_app
                  end
                end
              end
            end

            # Messaging only checkbox
            div do
              label do
                input type: "checkbox", name: "messaging_only", value: "true", 
                      checked: messaging_only, onchange: "this.form.submit()"
                text_node " Messaging Apps Only"
              end
            end
          end
        end
      end
    end

    if current_device.present?
      notifications = DeviceNotification.by_device(current_device)
                                         .recent
                                         .includes(:notification_media)
                                         .limit(200)
      
      notifications = notifications.by_app(current_app) if current_app.present?
      notifications = notifications.messaging_apps if messaging_only

      # Stats Panel
      panel "Statistics" do
        stats = {
          total: notifications.count,
          messaging: notifications.select(&:messaging_app?).count,
          with_images: notifications.count { |n| n.big_picture.present? },
          today: notifications.count { |n| n.display_time&.to_date == Date.current }
        }

        div class: "stats-grid", style: "display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px;" do
          [
            ["📊 Total", stats[:total], "#3498db"],
            ["💬 Messaging", stats[:messaging], "#2ecc71"],
            ["🖼️ With Images", stats[:with_images], "#9b59b6"],
            ["📅 Today", stats[:today], "#e74c3c"]
          ].each do |label, count, color|
            div style: "background: #{color}; padding: 20px; border-radius: 8px; color: white; text-align: center;" do
              h2 count, style: "margin: 0; font-size: 32px;"
              span label
            end
          end
        end
      end

      # Notifications List
      panel "Notifications" do
        if notifications.empty?
          div class: "empty-state", style: "text-align: center; padding: 40px; color: #7f8c8d;" do
            h3 "📭 No notifications found"
            para "Notifications from this device will appear here"
          end
        else
          table_for notifications do
            column "Time" do |n|
              if n.display_time
                div n.display_time.strftime("%Y-%m-%d"), style: "font-weight: bold;"
                div n.display_time.strftime("%H:%M:%S"), style: "color: #7f8c8d; font-size: 12px;"
              end
            end
            
            column "App" do |n|
              div style: "display: flex; align-items: center; gap: 10px;" do
                if n.large_icon&.data_uri
                  img src: n.large_icon.data_uri, style: "width: 32px; height: 32px; border-radius: 6px;"
                end
                div do
                  div n.app_name || n.package_name.split('.').last.capitalize, style: "font-weight: bold;"
                  div n.package_name, style: "color: #7f8c8d; font-size: 11px;"
                end
              end
            end
            
            column "Content" do |n|
              div do
                if n.title.present?
                  div n.title, style: "font-weight: bold; margin-bottom: 4px;"
                end
                if n.content.present?
                  div n.content.truncate(200), style: "color: #2c3e50;"
                end
                if n.sub_text.present?
                  div n.sub_text, style: "color: #7f8c8d; font-size: 12px; margin-top: 4px;"
                end
              end
            end
            
            column "Image" do |n|
              if n.big_picture&.data_uri
                a href: n.big_picture.data_uri, target: "_blank" do
                  img src: n.big_picture.data_uri, style: "max-width: 120px; max-height: 80px; border-radius: 4px; cursor: pointer;"
                end
              end
            end
            
            column "Type" do |n|
              badges = []
              badges << "💬 Chat" if n.messaging_app?
              badges << "🔄 Ongoing" if n.is_ongoing
              badges << "📌 #{n.category}" if n.category.present?
              
              div style: "display: flex; flex-wrap: wrap; gap: 4px;" do
                badges.each do |badge|
                  span badge, style: "background: #ecf0f1; padding: 2px 8px; border-radius: 12px; font-size: 11px;"
                end
              end
            end
          end
        end
      end
    else
      panel "No Devices" do
        div style: "text-align: center; padding: 40px;" do
          h3 "📱 No devices with notifications"
          para "When devices start sending notifications, they will appear here."
        end
      end
    end

    # Custom CSS
    div do
      style do
        raw <<-CSS
          .notifications-header { margin-bottom: 20px; }
          .filter-row select { padding: 8px 12px; border-radius: 4px; border: 1px solid #ddd; }
          table.index_table td { vertical-align: top; }
          table.index_table tr:hover { background: #f8f9fa; }
        CSS
      end
    end
  end

  sidebar "Help", priority: 0 do
    para "This page shows all notifications captured from connected devices."
    para "Use filters to narrow down by device, app, or messaging apps only."
    
    h4 "Messaging Apps Tracked:"
    ul do
      %w[WhatsApp Messenger Telegram Viber Instagram Snapchat Twitter Discord Skype].each do |app|
        li app
      end
    end
  end
end
