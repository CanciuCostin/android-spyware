class Admin::AndroidSettingsController < ApplicationController
  before_action :authenticate_admin_user!

  def update
    # Save to environment or settings file
    config = params[:config]
    
    # Update .env file
    env_path = Rails.root.join('.env')
    env_content = File.exist?(env_path) ? File.read(env_path) : ""
    
    # Update or add each config value
    updates = {
      'RAILS_HOST' => config[:server_url],
      'RAILS_PORT' => config[:server_port],
      'USE_SSL' => config[:use_ssl] == '1' ? 'true' : 'false',
      'TURN_SERVER' => config[:turn_server],
      'TURN_USER' => config[:turn_user],
      'TURN_PASSWORD' => config[:turn_password]
    }

    updates.each do |key, value|
      if env_content.match?(/^#{key}=/)
        env_content.gsub!(/^#{key}=.*$/, "#{key}=#{value}")
      else
        env_content += "\n#{key}=#{value}"
      end
    end

    File.write(env_path, env_content.strip + "\n")

    # Also update ENV for current process
    updates.each { |k, v| ENV[k] = v }

    flash[:notice] = "✅ Configuration saved successfully!"
    redirect_to admin_android_config_path
  end
end
