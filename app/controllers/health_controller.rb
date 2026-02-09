# frozen_string_literal: true

# Health Check Controller for Container Orchestration
# Provides liveness, readiness, startup, and detailed health checks
class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false
  skip_before_action :authenticate_admin_user!, raise: false
  
  # Detailed health check with all dependencies
  def index
    health_status = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: ENV['APP_VERSION'] || (Rails.application.config.respond_to?(:version) ? Rails.application.config.version : 'unknown'),
      environment: Rails.env,
      uptime_seconds: uptime_seconds,
      checks: {
        database: check_database,
        redis: check_redis,
        action_cable: check_action_cable,
        disk_space: check_disk_space,
        memory: check_memory
      }
    }
    
    all_healthy = health_status[:checks].values.all? { |c| c[:status] == 'ok' }
    health_status[:status] = 'degraded' unless all_healthy
    status_code = all_healthy ? :ok : :service_unavailable
    
    render json: health_status, status: status_code
  end
  
  # Readiness probe - can accept traffic (DB, Redis, ActionCable)
  def ready
    checks = {
      database: check_database,
      redis: check_redis,
      action_cable: check_action_cable
    }
    
    all_ready = checks.values.all? { |c| c[:status] == 'ok' }
    
    if all_ready
      render json: { 
        status: 'ready',
        timestamp: Time.current.iso8601,
        checks: checks
      }, status: :ok
    else
      render json: { 
        status: 'not_ready',
        timestamp: Time.current.iso8601,
        checks: checks
      }, status: :service_unavailable
    end
  end
  
  # Liveness probe - application is running
  def live
    render json: { 
      status: 'alive',
      timestamp: Time.current.iso8601,
      uptime_seconds: uptime_seconds,
      pid: Process.pid
    }, status: :ok
  end

  # Startup probe - initial readiness after boot
  def startup
    db_ok = check_database[:status] == 'ok'
    migrations_ok = begin
      ActiveRecord::Migration.check_all_pending!
      true
    rescue ActiveRecord::PendingMigrationError
      false
    rescue StandardError
      true # if check fails, assume ok
    end

    ready = db_ok && migrations_ok
    
    render json: {
      status: ready ? 'started' : 'starting',
      timestamp: Time.current.iso8601,
      uptime_seconds: uptime_seconds,
      database_connected: db_ok,
      migrations_current: migrations_ok
    }, status: ready ? :ok : :service_unavailable
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
    RedisPool.with { |redis| redis.ping }
    latency = ((Time.current - start_time) * 1000).round(2)
    
    { 
      status: 'ok',
      latency_ms: latency
    }
  rescue StandardError => e
    Rails.logger.error("Redis health check failed: #{e.message}")
    { status: 'error', error: e.message }
  end

  def check_action_cable
    cable_config = Rails.application.config.action_cable
    adapter = cable_config.cable&.dig('adapter') || ActionCable.server.config.cable&.dig('adapter') || 'unknown'

    if adapter == 'redis'
      RedisPool.with { |redis| redis.ping }
      { status: 'ok', adapter: adapter }
    else
      { status: 'ok', adapter: adapter }
    end
  rescue StandardError => e
    Rails.logger.error("ActionCable health check failed: #{e.message}")
    { status: 'error', adapter: adapter, error: e.message }
  end
  
  def check_disk_space
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
