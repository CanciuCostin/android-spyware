ActiveAdmin.register Smartphone do
  menu priority: 3, label: "📱 Smartphones", parent: "📦 APK"

  permit_params :name, :device_id, :operating_system, :is_rooted, :is_app_hidden

  index do
    selectable_column
    id_column
    column :name
    column :device_id
    column :operating_system
    column :is_rooted
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :name
      row :device_id
      row :operating_system
      row :created_at
    end

    panel "Integrity Report" do
      attributes_table_for smartphone do
        row :is_rooted
        row :is_app_hidden
        row "Root Status" do |s|
          s.is_rooted ? status_tag("Rooted", class: "error") : status_tag("Secure", class: "ok")
        end
      end
    end

    panel "Links" do
      link_to "Social Chats", admin_social_media_messages_path(q: { smartphone_id_eq: smartphone.id }), class: "button"
    end

    active_admin_comments
  end
end
