require_dependency 'ai_analyzer'
require_dependency 'ai_health_monitor'

ActiveAdmin.register_page "AI Analysis" do
  menu label: "🧠 AI Analysis", parent: "🧠 AI", priority: 2

  content do
    render partial: 'admin/ai_analysis'
  end

  page_action :behavior_report, method: :post do
    device_id = params[:device_id]
    period = (params[:period_days] || 7).to_i
    result = AiAnalyzer.behavior_report(device_id, period_days: period)
    render json: result
  end

  page_action :daily_summary, method: :post do
    device_id = params[:device_id]
    result = AiAnalyzer.daily_summary(device_id)
    render json: { summary: result }
  end

  page_action :analyze_data, method: :post do
    device_id = params[:device_id]
    data_type = params[:data_type]
    period = (params[:period_days] || 7).to_i
    result = AiAnalyzer.analyze_data(device_id, data_type, period_days: period)
    render json: result
  end

  page_action :anomaly_detection, method: :post do
    device_id = params[:device_id]
    period = (params[:period_days] || 30).to_i
    result = AiAnalyzer.detect_anomalies(device_id, period_days: period)
    render json: { anomalies: result }
  end
end
