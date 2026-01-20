ActiveAdmin.register_page "Tracing" do
  menu priority: 20, label: "🔍 Observability"

  content title: "System Tracing (Jaeger)" do
    columns do
      column do
        panel "Status" do
          para "Tracing is enabled. All actions are being recorded."
          para "Jaeger URL: http://localhost:16686"
        end
      end
    end

    panel "Jaeger UI" do
      # Embedding Jaeger. Note: This requires the user's browser to reach localhost:16686
      text_node %{<iframe src="http://localhost:16686" width="100%" height="800px" style="border:none;"></iframe>}.html_safe
    end
  end
end
