# frozen_string_literal: true

module Api
  class PreferencesController < ActionController::Base
    skip_before_action :verify_authenticity_token
    before_action :authenticate_admin!
    respond_to :json

    # GET /api/preferences
    def index
      preferences = PreferenceService.get_for(current_admin_user)
      render json: { preferences: preferences, defaults: PreferenceService.defaults }
    end

    # PUT /api/preferences
    def update
      preferences = PreferenceService.update_for(current_admin_user, preference_params)
      render json: { preferences: preferences }
    end

    # DELETE /api/preferences
    def destroy
      preferences = PreferenceService.reset_for(current_admin_user)
      render json: { preferences: preferences, message: 'Preferences reset to defaults' }
    end

    private

    def authenticate_admin!
      unless current_admin_user
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
    end

    def current_admin_user
      @current_admin_user ||= begin
        return env['warden']&.user(:admin_user) if defined?(env) && env['warden']
        nil
      end
    end

    def preference_params
      return {} unless params[:preferences].is_a?(ActionController::Parameters) || params[:preferences].is_a?(Hash)

      params[:preferences].to_unsafe_h
    end
  end
end
