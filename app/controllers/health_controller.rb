# frozen_string_literal: true

# Health Check Controller for Container Orchestration
# Provides liveness, readiness, and detailed health checks
class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_admin_user!, if: -> { respond_to?(:authenticate_admin_user!) }
  
  # Detailed health check with all dependencies
  def index
    health_status = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: ENV['APP_VERSION'] || Rails.application.config.version || 'unknown',
      environment: Rails.env,
      checks: {
        database: check_database,
        redis: check_redis,
        disk_space: check_disk_space,
        memory: check_memory
      }
    }
    
    all_healthy = health_status[:checks].values.all? { |c| c[:status] == 'ok' }
    status_code = all_healthy ? :ok : :service_unavailable
    
    render json: health_status, status: status_code
  end
  
  # Readiness probe - can accept traffic
  def ready
    db_check = check_database
    redis_check = check_redis
    
    if db_check[:status] == 'ok' && redis_check[:status] == 'ok'
      render json: { 
        status: 'ready',
        timestamp: Time.current.iso8601 
      }, status: :ok
    else
      render json: { 
        status: 'not ready',
        database: db_check,
        redis: redis_check,
        timestamp: Time.current.iso8601 
      }, status: :service_unavailable
    end
  end
  
  # Liveness probe - application is running
  def live
    render json: { 
      status: 'alive',
      timestamp: Time.current.iso8601,
      uptime: uptime_seconds
    }, status: :ok
  end
  
  private
  
  def check_database
    start_time = Time.current
    ActiveRecord::Base.connection.execute('SELECT 1')
    latency = ((Time.current - start_time) * 1000).round(2)
    
    { 
      status: 'ok', 
      latency_ms: latency,
      pool_size: ActiveRecord::Base.connection_pool.size,
      active_connections: ActiveRecord::Base.connection_pool.connections.size
    }
  rescue StandardError => e
    Rails.logger.error("Database health check failed: #{e.message}")
    { status: 'error', error: e.message }
  end
  
  def check_redis
    start_time = Time.current
    redis = Redis.new(url: ENV['REDIS_URL'])
    redis.ping
    latency = ((Time.current - start_time) * 1000).round(2)
    
    { 
      status: 'ok',
      latency_ms: latency
    }
  rescue StandardError => e
    Rails.logger.error("Redis health check failed: #{e.message}")
    { status: 'error', error: e.message }
  ensure
    redis&.close
  end
  
  def check_disk_space
    # Works on both Linux and Windows
    if Gem.win_platform?
      usage = `wmic logicaldisk get size,freespace,caption | findstr "C:"`.split
      total = usage[1].to_i
      free = usage[2].to_i
      used_percent = total > 0 ? (((total - free).to_f / total) * 100).round : 0
    else
      usage = `df -h / | tail -1 | awk '{print $5}' | sed 's/%//'`.to_i
      used_percent = usage
    end
    
    { 
      status: used_percent < 90 ? 'ok' : 'warning', 
      usage_percent: used_percent 
    }
  rescue StandardError => e
    Rails.logger.error("Disk space check failed: #{e.message}")
    { status: 'unknown', error: e.message }
  end
  
  def check_memory
    # Works on both Linux and Windows
    if Gem.win_platform?
      mem_info = `wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /Value`.split("\n")
      total = mem_info.find { |l| l.include?('TotalVisibleMemorySize') }&.split('=')&.last&.to_i || 0
      free = mem_info.find { |l| l.include?('FreePhysicalMemory') }&.split('=')&.last&.to_i || 0
      used = total - free
      usage_percent = total > 0 ? ((used.to_f / total) * 100).round : 0
    else
      total = `free -m | grep Mem | awk '{print $2}'`.to_i
      used = `free -m | grep Mem | awk '{print $3}'`.to_i
      usage_percent = total > 0 ? ((used.to_f / total) * 100).round : 0
    end
    
    { 
      status: usage_percent < 90 ? 'ok' : 'warning', 
      usage_percent: usage_percent 
    }
  rescue StandardError => e
    Rails.logger.error("Memory check failed: #{e.message}")
    { status: 'unknown', error: e.message }
  end
  
  def uptime_seconds
    (Time.current - Rails.application.config.boot_time).to_i rescue 0
  end
end
