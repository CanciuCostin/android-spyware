ActiveAdmin.register TrackedError, as: "Error Tracking" do
  menu priority: 12, label: "🐛 Error Tracking"

  actions :index, :show

  scope :all, default: true
  scope :open_errors, label: "Open"
  scope :resolved
  scope :ignored

  filter :error_class
  filter :message
  filter :status, as: :select, collection: TrackedError::STATUSES
  filter :count
  filter :first_seen_at
  filter :last_seen_at

  index title: "🐛 Error Tracking" do
    selectable_column
    id_column
    column :error_class
    column("Message") { |e| truncate(e.message, length: 80) }
    column :count
    column("Devices") { |e| e.affected_device_count }
    column :status do |e|
      status_tag e.status, class: case e.status
                                  when 'open' then 'error'
                                  when 'resolved' then 'ok'
                                  when 'ignored' then 'warning'
                                  end
    end
    column :first_seen_at
    column :last_seen_at
    actions defaults: true do |error|
      if error.status == 'open'
        item "Resolve", resolve_admin_error_tracking_path(error), method: :put, class: "member_link"
        item "Ignore", ignore_admin_error_tracking_path(error), method: :put, class: "member_link"
      elsif error.status != 'open'
        item "Reopen", reopen_admin_error_tracking_path(error), method: :put, class: "member_link"
      end
    end
  end

  show title: proc { |e| "Error: #{e.error_class}" } do
    attributes_table do
      row :id
      row :fingerprint
      row :error_class
      row :message
      row :count
      row :status do |e|
        status_tag e.status
      end
      row("Affected Devices") { |e| e.affected_device_count }
      row :device_ids do |e|
        (e.device_ids || []).join(', ')
      end
      row :first_seen_at
      row :last_seen_at
      row :resolved_at
      row :backtrace do |e|
        pre (e.backtrace || []).join("\n")
      end
    end
  end

  member_action :resolve, method: :put do
    unless current_admin_user
      redirect_to admin_root_path, alert: "Unauthorized"
      return
    end
    resource.resolve!
    redirect_to resource_path(resource), notice: "Error marked as resolved."
  end

  member_action :ignore, method: :put do
    unless current_admin_user
      redirect_to admin_root_path, alert: "Unauthorized"
      return
    end
    resource.ignore!
    redirect_to resource_path(resource), notice: "Error marked as ignored."
  end

  member_action :reopen, method: :put do
    unless current_admin_user
      redirect_to admin_root_path, alert: "Unauthorized"
      return
    end
    resource.reopen!
    redirect_to resource_path(resource), notice: "Error reopened."
  end

  batch_action :resolve do |ids|
    batch_action_collection.find(ids).each(&:resolve!)
    redirect_to collection_path, notice: "#{ids.size} errors resolved."
  end

  batch_action :ignore do |ids|
    batch_action_collection.find(ids).each(&:ignore!)
    redirect_to collection_path, notice: "#{ids.size} errors ignored."
  end

  # Stats sidebar
  sidebar "Error Statistics", only: :index do
    stats = ErrorAggregator.stats
    attributes_table_for stats do
      row("Total Errors") { stats[:total] }
      row("Open") { stats[:open] }
      row("Resolved") { stats[:resolved] }
      row("Ignored") { stats[:ignored] }
      row("Total Occurrences") { stats[:total_occurrences] }
    end
  end
end
