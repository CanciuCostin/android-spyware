# frozen_string_literal: true

# Adds a menu link to the Sidekiq Web UI inside ActiveAdmin.
# Requires `sidekiq/web` to be mounted in routes.rb.
if defined?(ActiveAdmin)
  ActiveAdmin.register_page "Sidekiq" do
    menu label: "⚙️ Background Jobs", priority: 90

    content title: "⚙️ Background Jobs" do
      div class: "sidekiq-dashboard" do
        para do
          text_node "Sidekiq Web UI is available at "
          a href: "/sidekiq", target: "_blank" do
            strong "/sidekiq"
          end
          text_node " (requires authentication)."
        end

        h3 "Queue Overview"

        table_for Sidekiq::Queue.all do
          column("Queue")  { |q| q.name }
          column("Size")   { |q| q.size }
          column("Latency") { |q| "#{q.latency.round(2)}s" }
        end if defined?(Sidekiq::Queue)

        h3 "Process Stats"

        stats = Sidekiq::Stats.new if defined?(Sidekiq::Stats)
        if stats
          attributes_table_for stats do
            row("Processed")  { stats.processed }
            row("Failed")     { stats.failed }
            row("Enqueued")   { stats.enqueued }
            row("Scheduled")  { stats.scheduled_size }
            row("Retries")    { stats.retry_size }
            row("Dead")       { stats.dead_size }
          end
        end
      end
    end
  end
end
