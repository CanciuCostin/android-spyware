module Api
  class NotificationsController < Api::BaseController
    
    # POST /api/notifications
    def receive
      notifications_data = params[:notifications] || [params]
      
      notifications_data.each do |notification_params|
        create_notification(notification_params)
      end
      
      render json: { 
        status: 'success', 
        received: notifications_data.size,
        timestamp: Time.current.to_i 
      }
    rescue StandardError => e
      Rails.logger.error "Notification receive error: #{e.message}"
      render json: { status: 'error', message: e.message }, status: :unprocessable_entity
    end
    
    # GET /api/notifications/:device_id
    def index
      device_id = params[:device_id]
      
      notifications = DeviceNotification.by_device(device_id)
                                         .recent
                                         .includes(:notification_media)
      
      # Apply filters
      notifications = notifications.by_app(params[:app]) if params[:app].present?
      notifications = notifications.messaging_apps if params[:messaging_only] == 'true'
      notifications = notifications.limit(params[:limit] || 100)
      
      render json: {
        device_id: device_id,
        count: notifications.size,
        notifications: notifications.map { |n| notification_json(n) }
      }
    end
    
    private
    
    def create_notification(data)
      notification = DeviceNotification.create!(
        device_id: data[:device_id],
        package_name: data[:package_name],
        app_name: data[:app_name],
        title: data[:title],
        content: data[:content],
        sub_text: data[:sub_text],
        category: data[:category],
        notification_id: data[:notification_id],
        group_key: data[:group_key],
        is_ongoing: data[:is_ongoing] || false,
        is_clearable: data[:is_clearable].nil? ? true : data[:is_clearable],
        post_time: data[:post_time],
        received_at: Time.current
      )
      
      # Save media if present
      save_media(notification, 'large_icon', data[:large_icon]) if data[:large_icon].present?
      save_media(notification, 'big_picture', data[:big_picture]) if data[:big_picture].present?
      
      notification
    end
    
    def save_media(notification, media_type, base64_data)
      return unless base64_data.present?
      
      # SECURITY: Validate base64 length BEFORE decoding to prevent memory exhaustion
      # Max 5MB encoded = ~3.75MB decoded (base64 is ~4/3 ratio)
      max_base64_size = 5 * 1024 * 1024  # 5MB encoded
      if base64_data.bytesize > max_base64_size
        Rails.logger.warn "Rejected oversized base64 for #{media_type}: #{base64_data.bytesize} bytes"
        return
      end
      
      binary_data = Base64.decode64(base64_data)
      return unless reject_oversize!(binary_data.bytesize, "notification #{media_type}")
      mime_type = detect_mime_type(binary_data)
      
      notification.notification_media.create!(
        media_type: media_type,
        data: binary_data,
        mime_type: mime_type
      )
    rescue StandardError => e
      Rails.logger.error "Failed to save #{media_type}: #{e.message}"
    end
    
    def detect_mime_type(data)
      return 'image/png' if data[0..7].bytes == [137, 80, 78, 71, 13, 10, 26, 10]
      return 'image/jpeg' if data[0..1].bytes == [255, 216]
      return 'image/gif' if data[0..2] == 'GIF'
      return 'image/webp' if data[0..3] == 'RIFF' && data[8..11] == 'WEBP'
      'image/png' # Default
    end
    
    def notification_json(notification)
      {
        id: notification.id,
        package_name: notification.package_name,
        app_name: notification.app_name,
        title: notification.title,
        content: notification.content,
        sub_text: notification.sub_text,
        category: notification.category,
        post_time: notification.post_time,
        display_time: notification.display_time&.iso8601,
        is_ongoing: notification.is_ongoing,
        is_messaging_app: notification.messaging_app?,
        has_large_icon: notification.large_icon.present?,
        has_big_picture: notification.big_picture.present?,
        large_icon_url: notification.large_icon&.data_uri,
        big_picture_url: notification.big_picture&.data_uri
      }
    end
  end
end
