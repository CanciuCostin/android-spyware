module Api
  class BaseController < ApplicationController
    include Api::SmartphoneFinder
    
    skip_before_action :verify_authenticity_token
    before_action :authenticate_device!
    respond_to :json
    
    # Simple device authentication mock - can be expanded
    def authenticate_device!
       token = request.headers['X-Device-Token'] || params[:token]
       sys_token = File.read(Rails.root.join('config/device_secret.token')).strip rescue "default_insecure"
       
       # In dev mode we might allow bypass, but for beast mode we check
       unless token == sys_token
         render json: { error: "Unauthorized. Invalid Token." }, status: :unauthorized
       end
    end
  end
end
