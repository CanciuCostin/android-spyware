namespace :audit do
  desc "Generate compliance report"
  task :report, [:start_date, :end_date] => :environment do |t, args|
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : 30.days.ago.to_date
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.today
    
    puts "=" * 80
    puts "Audit Trail Compliance Report"
    puts "=" * 80
    puts "Period: #{start_date} to #{end_date}"
    puts "Generated: #{Time.current.iso8601}"
    puts "=" * 80
    puts
    
    logs = AuditLog.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    
    puts "SUMMARY"
    puts "-" * 80
    puts "Total actions logged: #{logs.count}"
    puts "Unique admin users: #{logs.distinct.count(:admin_user_id)}"
    puts "Unique IP addresses: #{logs.where.not(ip_address: nil).distinct.count(:ip_address)}"
    puts
    
    puts "ACTIONS BY TYPE"
    puts "-" * 80
    logs.group(:action).count.sort_by { |_, count| -count }.each do |action, count|
      percentage = (count.to_f / logs.count * 100).round(2)
      puts "  #{action.ljust(15)}: #{count.to_s.rjust(8)} (#{percentage}%)"
    end
    puts
    
    puts "ACTIONS BY USER"
    puts "-" * 80
    user_actions = logs.joins(:admin_user).group('admin_users.email').count.sort_by { |_, count| -count }
    user_actions.take(20).each do |email, count|
      puts "  #{email.ljust(40)}: #{count.to_s.rjust(8)}"
    end
    if user_actions.size > 20
      puts "  ... and #{user_actions.size - 20} more users"
    end
    puts
    
    puts "ACTIONS BY RESOURCE TYPE"
    puts "-" * 80
    resource_counts = logs.where.not(auditable_type: nil).group(:auditable_type).count.sort_by { |_, count| -count }
    resource_counts.each do |type, count|
      puts "  #{type.ljust(30)}: #{count.to_s.rjust(8)}"
    end
    puts
    
    puts "TOP IP ADDRESSES"
    puts "-" * 80
    ip_counts = logs.where.not(ip_address: nil).group(:ip_address).count.sort_by { |_, count| -count }
    ip_counts.take(10).each do |ip, count|
      puts "  #{ip.ljust(20)}: #{count.to_s.rjust(8)}"
    end
    puts
    
    puts "DAILY ACTIVITY"
    puts "-" * 80
    daily_counts = logs.group("DATE(created_at)").count.sort_by { |date, _| date }
    daily_counts.each do |date, count|
      bar = '#' * (count / [daily_counts.values.max / 50, 1].max)
      puts "  #{date} | #{count.to_s.rjust(6)} | #{bar}"
    end
    puts
    
    puts "=" * 80
    puts "End of Report"
    puts "=" * 80
  end
  
  desc "Export audit logs to CSV"
  task :export, [:start_date, :end_date, :output_file] => :environment do |t, args|
    require 'csv'
    
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : 30.days.ago.to_date
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.today
    output_file = args[:output_file] || "audit_export_#{Date.today}.csv"
    
    logs = AuditLog
      .includes(:admin_user)
      .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      .order(created_at: :desc)
    
    CSV.open(output_file, 'w', headers: true) do |csv|
      csv << ['ID', 'Timestamp', 'Admin User', 'Action', 'Resource Type', 'Resource ID',
              'IP Address', 'User Agent', 'Request Method', 'Request Path', 
              'Response Status', 'Changes']
      
      logs.find_each do |log|
        csv << [
          log.id,
          log.created_at.iso8601,
          log.admin_user&.email || 'System',
          log.action,
          log.auditable_type,
          log.auditable_id,
          log.ip_address,
          log.user_agent,
          log.request_method,
          log.request_path,
          log.response_status,
          log.changes.to_json
        ]
      end
    end
    
    puts "Exported #{logs.count} audit logs to #{output_file}"
  end
  
  desc "Cleanup old audit logs (older than specified days, default: 365)"
  task :cleanup, [:days] => :environment do |t, args|
    days = (args[:days] || 365).to_i
    cutoff_date = days.days.ago
    
    puts "Cleaning up audit logs older than #{days} days (before #{cutoff_date.to_date})..."
    
    # Note: This will fail due to immutability trigger, but included for reference
    # In production, you may want to archive to cold storage instead
    count = AuditLog.where('created_at < ?', cutoff_date).count
    
    if count > 0
      puts "Found #{count} logs to archive/cleanup"
      puts "WARNING: Direct deletion is prevented by database trigger."
      puts "Consider archiving to cold storage instead."
    else
      puts "No logs found older than #{days} days"
    end
  end
  
  desc "Verify audit log integrity"
  task :verify => :environment do
    puts "Verifying audit log integrity..."
    puts
    
    total = AuditLog.count
    puts "Total audit logs: #{total}"
    
    # Check for any gaps in IDs (potential deletion attempts)
    if total > 0
      expected_ids = (AuditLog.minimum(:id)..AuditLog.maximum(:id)).to_a
      actual_ids = AuditLog.pluck(:id).sort
      missing_ids = expected_ids - actual_ids
      
      if missing_ids.any?
        puts "WARNING: Found #{missing_ids.size} missing ID(s) - potential deletion detected!"
        puts "Missing IDs: #{missing_ids.take(10).join(', ')}#{missing_ids.size > 10 ? '...' : ''}"
      else
        puts "✓ No missing IDs detected - log sequence intact"
      end
    end
    
    # Check for logs with missing required data
    incomplete = AuditLog.where(action: nil).or(AuditLog.where(created_at: nil)).count
    if incomplete > 0
      puts "WARNING: Found #{incomplete} logs with missing required data"
    else
      puts "✓ All logs have required fields"
    end
    
    # Check for orphaned logs (auditable deleted)
    orphaned = AuditLog.where.not(auditable_type: nil)
      .where.not(auditable_id: nil)
      .select { |log| log.auditable.nil? rescue true }
      .size
    
    puts "Found #{orphaned} logs referencing deleted resources (expected behavior)"
    
    puts
    puts "Integrity check complete"
  end
end
