class Admin::AndroidSettingsController < ApplicationController
  before_action :authenticate_admin_user!

  def update
    # Save to environment or settings file with validation
    config = params[:config]
    
    # Validate inputs to prevent injection
    server_url = config[:server_url].to_s.strip
    server_port = config[:server_port].to_s.strip
    turn_server = config[:turn_server].to_s.strip
    turn_user = config[:turn_user].to_s.strip
    turn_password = config[:turn_password].to_s.strip
    
    # Validate server_url (IP or domain)
    unless server_url =~ /\A[a-zA-Z0-9.\-]+\z/
      flash[:error] = "❌ Invalid server URL format"
      redirect_to admin_android_config_path and return
    end
    
    # Validate port (1-65535)
    unless server_port =~ /\A\d{1,5}\z/ && server_port.to_i.between?(1, 65535)
      flash[:error] = "❌ Invalid port number"
      redirect_to admin_android_config_path and return
    end
    
    # Validate TURN server format
    unless turn_server =~ /\A(turn|turns):[a-zA-Z0-9.\-]+:\d{1,5}\z/
      flash[:error] = "❌ Invalid TURN server format (expected: turn:host:port)"
      redirect_to admin_android_config_path and return
    end
    
    # Validate username (alphanumeric + underscore)
    unless turn_user =~ /\A[a-zA-Z0-9_]+\z/
      flash[:error] = "❌ Invalid TURN username"
      redirect_to admin_android_config_path and return
    end
    
    # Update .env file
    env_path = Rails.root.join('.env')
    env_content = File.exist?(env_path) ? File.read(env_path) : ""
    
    # Update or add each config value (now validated)
    updates = {
      'RAILS_HOST' => server_url,
      'RAILS_PORT' => server_port,
      'USE_SSL' => config[:use_ssl] == '1' ? 'true' : 'false',
      'TURN_SERVER' => turn_server,
      'TURN_USER' => turn_user,
      'TURN_PASSWORD' => turn_password
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
