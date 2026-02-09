ActiveAdmin.register_page "AI Reports" do
  menu label: "📄 AI Reports", parent: "🧠 AI", priority: 4

  content title: "📄 AI Report Generation" do
    devices = Smartphone.all

    if devices.empty?
      div class: "empty-state" do
        h2 "No Devices Available"
        para "Connect a device to generate reports."
      end
    else
      # Device & template selector
      div class: "report-controls" do
        div class: "control-row" do
          label "Device:", for: "report-device-select"
          select id: "report-device-select", class: "device-select-dropdown" do
            devices.each do |device|
              option value: device.id do
                text_node "#{device.name} (#{device.device_id})"
              end
            end
          end

          label "Template:", for: "report-template-select", style: "margin-left: 16px;"
          select id: "report-template-select" do
            ReportGenerationService::TEMPLATES.each do |tmpl|
              option(value: tmpl) { tmpl.titleize }
            end
          end

          label "Period:", for: "report-period-select", style: "margin-left: 16px;"
          select id: "report-period-select" do
            %w[daily weekly monthly].each do |p|
              option(value: p) { p.capitalize }
            end
          end

          label "Format:", for: "report-format-select", style: "margin-left: 16px;"
          select id: "report-format-select" do
            %w[json html].each do |f|
              option(value: f) { f.upcase }
            end
          end
        end

        div class: "control-row", style: "margin-top: 12px;" do
          button "📊 Generate Report", id: "generate-report-btn", class: "button"
          button "🛡️ Risk Assessment", id: "risk-assessment-btn", class: "button", style: "margin-left: 8px;"
        end
      end

      # Risk assessment card
      div id: "risk-assessment-card", class: "risk-card", style: "display: none;" do
        h3 "Risk Assessment"
        div id: "risk-score", class: "risk-score"
        div id: "risk-factors", class: "risk-factors"
      end

      # Report output
      div id: "report-output", class: "report-output" do
        pre id: "report-json", style: "white-space: pre-wrap; max-height: 600px; overflow: auto; background: #1e293b; padding: 16px; border-radius: 8px; color: #e2e8f0;"
      end
    end

    script do
      text_node <<~JS.html_safe
        document.addEventListener('DOMContentLoaded', function() {
          var generateBtn = document.getElementById('generate-report-btn');
          var riskBtn = document.getElementById('risk-assessment-btn');
          if (!generateBtn) return;

          generateBtn.addEventListener('click', function() {
            var deviceId = document.getElementById('report-device-select').value;
            var template = document.getElementById('report-template-select').value;
            var period = document.getElementById('report-period-select').value;
            var format = document.getElementById('report-format-select').value;

            fetch('/api/ai/reports/generate', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ device_id: deviceId, template: template, period: period, format: format })
            })
            .then(function(r) { return r.json(); })
            .then(function(data) {
              document.getElementById('report-json').textContent = JSON.stringify(data, null, 2);
            })
            .catch(function(e) {
              document.getElementById('report-json').textContent = 'Error: ' + e.message;
            });
          });

          riskBtn.addEventListener('click', function() {
            var deviceId = document.getElementById('report-device-select').value;
            fetch('/api/ai/reports/risk_assessment', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ device_id: deviceId })
            })
            .then(function(r) { return r.json(); })
            .then(function(data) {
              var card = document.getElementById('risk-assessment-card');
              card.style.display = 'block';
              var ra = data.risk_assessment || {};
              document.getElementById('risk-score').innerHTML = '<strong>Score:</strong> ' + (ra.score || 0) + '/100 (' + (ra.level || 'unknown').toUpperCase() + ')';
              var factors = (ra.factors || []).map(function(f) { return '<li>' + f.detail + '</li>'; }).join('');
              document.getElementById('risk-factors').innerHTML = '<ul>' + factors + '</ul>';
            });
          });
        });
      JS
    end

    style do
      raw <<~CSS
        .report-controls { background: #1e293b; padding: 16px; border-radius: 8px; margin-bottom: 16px; }
        .control-row { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; }
        .control-row label { color: #94a3b8; font-weight: 600; }
        .control-row select { background: #334155; color: #e2e8f0; border: 1px solid #475569; border-radius: 4px; padding: 6px 10px; }
        .button { background: #3b82f6; color: white; border: none; border-radius: 4px; padding: 8px 16px; cursor: pointer; font-weight: 600; }
        .button:hover { background: #2563eb; }
        .risk-card { background: #1e293b; padding: 16px; border-radius: 8px; margin-bottom: 16px; border-left: 4px solid #f59e0b; }
        .risk-score { font-size: 1.3em; color: #e2e8f0; margin: 8px 0; }
        .risk-factors ul { color: #94a3b8; }
      CSS
    end
  end
end
