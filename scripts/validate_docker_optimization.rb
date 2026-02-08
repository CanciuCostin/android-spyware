#!/usr/bin/env ruby
# frozen_string_literal: true

# Docker Optimization Validation Script
# Validates that all optimizations are properly configured

require 'json'
require 'yaml'

class DockerOptimizationValidator
  CHECKS = {
    files: [
      'docker/app-rails-server/Dockerfile',
      'docker/docker-compose.yml',
      'frontend/Dockerfile',
      'frontend/nginx.conf',
      'app/controllers/health_controller.rb',
      'config/routes.rb',
      '.dockerignore',
      'frontend/.dockerignore'
    ],
    health_endpoints: [
      '/health',
      '/health/ready',
      '/health/live'
    ]
  }.freeze

  def initialize
    @errors = []
    @warnings = []
    @passed = 0
  end

  def run
    puts "🔍 Docker Optimization Validation"
    puts "=" * 50
    puts

    check_required_files
    check_dockerfile_optimization
    check_docker_compose
    check_health_routes
    check_dockerignore
    check_running_containers if containers_running?

    print_summary
    exit(@errors.empty? ? 0 : 1)
  end

  private

  def check_required_files
    puts "📄 Checking required files..."
    CHECKS[:files].each do |file|
      if File.exist?(file)
        pass("✓ #{file}")
      else
        error("✗ #{file} not found")
      end
    end
    puts
  end

  def check_dockerfile_optimization
    puts "🏗️  Checking Dockerfile optimizations..."
    
    dockerfile = 'docker/app-rails-server/Dockerfile'
    if File.exist?(dockerfile)
      content = File.read(dockerfile)
      
      check_feature(content.include?('AS builder'), 'Multi-stage build')
      check_feature(content.include?('USER rails'), 'Non-root user')
      check_feature(content.include?('HEALTHCHECK'), 'Health check')
      check_feature(content.include?('ruby:2.6.6-slim'), 'Slim base image')
      check_feature(content.include?('--no-install-recommends'), 'Minimal dependencies')
      check_feature(content.include?('assets:precompile'), 'Asset precompilation')
    end
    puts
  end

  def check_docker_compose
    puts "🐳 Checking docker-compose configuration..."
    
    compose_file = 'docker/docker-compose.yml'
    if File.exist?(compose_file)
      begin
        config = YAML.load_file(compose_file)
        services = config['services'] || {}
        
        services.each do |name, service|
          check_service_health(name, service)
          check_service_resources(name, service)
          check_service_logging(name, service)
        end
      rescue => e
        error("Failed to parse docker-compose.yml: #{e.message}")
      end
    end
    puts
  end

  def check_service_health(name, service)
    if service['healthcheck']
      pass("✓ #{name}: Health check configured")
    else
      warn("⚠ #{name}: No health check configured")
    end
  end

  def check_service_resources(name, service)
    if service.dig('deploy', 'resources', 'limits')
      pass("✓ #{name}: Resource limits configured")
    else
      warn("⚠ #{name}: No resource limits")
    end
  end

  def check_service_logging(name, service)
    if service['logging']
      pass("✓ #{name}: Logging configured")
    else
      warn("⚠ #{name}: No logging limits")
    end
  end

  def check_health_routes
    puts "🏥 Checking health endpoints..."
    
    routes_file = 'config/routes.rb'
    if File.exist?(routes_file)
      content = File.read(routes_file)
      
      CHECKS[:health_endpoints].each do |endpoint|
        if content.include?(endpoint)
          pass("✓ Route configured: #{endpoint}")
        else
          error("✗ Route missing: #{endpoint}")
        end
      end
    end
    puts
  end

  def check_dockerignore
    puts "🚫 Checking .dockerignore..."
    
    ['.dockerignore', 'frontend/.dockerignore'].each do |file|
      if File.exist?(file)
        content = File.read(file)
        size = content.lines.count
        pass("✓ #{file} (#{size} rules)")
      else
        warn("⚠ #{file} not found")
      end
    end
    puts
  end

  def check_running_containers
    puts "🔄 Checking running containers..."
    
    output = `docker ps --format "{{.Names}}\t{{.Status}}\t{{.Health}}" 2>&1`
    
    if $?.success?
      output.each_line do |line|
        name, status, health = line.strip.split("\t")
        next unless name
        
        if health&.include?('healthy')
          pass("✓ #{name}: #{health}")
        elsif health&.include?('unhealthy')
          error("✗ #{name}: #{health}")
        else
          info("  #{name}: #{status} (no health check)")
        end
      end
    else
      info("  No containers running or Docker not available")
    end
    puts
  end

  def check_feature(condition, feature)
    if condition
      pass("✓ #{feature}")
    else
      warn("⚠ #{feature} not found")
    end
  end

  def containers_running?
    `docker ps -q 2>&1`.strip != ''
  end

  def pass(msg)
    puts "  \e[32m#{msg}\e[0m"
    @passed += 1
  end

  def warn(msg)
    puts "  \e[33m#{msg}\e[0m"
    @warnings << msg
  end

  def error(msg)
    puts "  \e[31m#{msg}\e[0m"
    @errors << msg
  end

  def info(msg)
    puts "  \e[36m#{msg}\e[0m"
  end

  def print_summary
    puts "=" * 50
    puts
    puts "📊 Summary:"
    puts "  Passed:   #{@passed}"
    puts "  Warnings: #{@warnings.count}"
    puts "  Errors:   #{@errors.count}"
    puts
    
    if @errors.empty? && @warnings.empty?
      puts "  \e[32m✅ All Docker optimizations are properly configured!\e[0m"
    elsif @errors.empty?
      puts "  \e[33m⚠️  Optimizations configured with some warnings\e[0m"
    else
      puts "  \e[31m❌ Some optimizations are missing or misconfigured\e[0m"
    end
    puts
  end
end

# Run validation
DockerOptimizationValidator.new.run if __FILE__ == $PROGRAM_NAME
