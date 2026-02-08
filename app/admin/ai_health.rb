require_dependency 'ai_health_monitor'

ActiveAdmin.register_page "AI Health" do
  menu label: "🔍 AI Health", parent: "🧠 AI", priority: 3

  content do
    render partial: 'admin/ai_health'
  end

  page_action :full_check, method: :post do
    result = AiHealthMonitor.full_health_check
    render json: result
  end

  page_action :quick_status, method: :get do
    result = AiHealthMonitor.quick_status
    render json: result
  end

  page_action :analyze_logs, method: :post do
    result = AiHealthMonitor.analyze_logs
    render json: result
  end

  page_action :suggestions, method: :post do
    result = AiHealthMonitor.get_suggestions
    render json: result
  end

  page_action :command_stats, method: :get do
    hours = (params[:hours] || 24).to_i
    result = AiHealthMonitor.command_stats(period_hours: hours)
    render json: result
  end
end
