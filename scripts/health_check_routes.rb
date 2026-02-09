# CI/CD Health Check Endpoint
# Add this to config/routes.rb if not already present

Rails.application.routes.draw do
  # Health check endpoint for load balancers and deployments
  get '/health', to: proc { [200, { 'Content-Type' => 'application/json' }, [{ status: 'ok', timestamp: Time.now.iso8601 }.to_json]] }
  
  # API health check
  namespace :api do
    get '/health', to: proc { [200, { 'Content-Type' => 'application/json' }, [{ status: 'healthy', version: ENV['APP_VERSION'] || 'unknown' }.to_json]] }
  end
end
