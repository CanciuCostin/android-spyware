# frozen_string_literal: true

ActiveAdmin.register ScheduledCommand do
  menu priority: 8, label: "⏰ Scheduled Commands"

  permit_params :smartphone_id, :command, :schedule_type, :cron_expression,
                :next_run_at, :active, :max_runs, :name, :description, params: {}

  scope :all, default: true
  scope :active
  scope :inactive
  scope(:due) { |scope| scope.due }
  scope(:once_type) { |scope| scope.once_type }
  scope(:recurring_type) { |scope| scope.recurring_type }

  filter :smartphone, as: :select, collection: -> { Smartphone.pluck(:name, :id) }
  filter :command, as: :select, collection: -> { CommandSender::ALLOWED_COMMANDS }
  filter :schedule_type, as: :select, collection: ScheduledCommand.schedule_types
  filter :active
  filter :last_status, as: :select, collection: %w[success failed timeout]
  filter :next_run_at
  filter :created_at

  index do
    selectable_column
    id_column
    column :name
    column :smartphone do |sc|
      link_to sc.smartphone.name, admin_apk_installation_path(sc.smartphone.apk_installation)
    rescue StandardError
      sc.smartphone_id
    end
    column :command
    column :schedule_type do |sc|
      status_tag sc.schedule_type, class: sc.recurring? ? 'blue' : 'orange'
    end
    column :cron_expression
    column :active do |sc|
      status_tag(sc.active? ? 'Active' : 'Inactive', class: sc.active? ? 'green' : 'red')
    end
    column :next_run_at
    column :last_run_at
    column :run_count
    column :last_status do |sc|
      if sc.last_status.present?
        color = case sc.last_status
                when 'success' then 'green'
                when 'failed' then 'red'
                when 'timeout' then 'orange'
                else 'grey'
                end
        status_tag sc.last_status, class: color
      end
    end
    actions defaults: true do |sc|
      item(sc.active? ? 'Disable' : 'Enable', toggle_admin_scheduled_command_path(sc), method: :post, class: 'member_link')
    end
  end

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :smartphone do |sc|
        "#{sc.smartphone.name} (#{sc.smartphone.device_id})"
      rescue StandardError
        sc.smartphone_id
      end
      row :command
      row :params do |sc|
        pre JSON.pretty_generate(sc.params || {})
      end
      row :schedule_type
      row :cron_expression
      row :active do |sc|
        status_tag(sc.active? ? 'Active' : 'Inactive', class: sc.active? ? 'green' : 'red')
      end
      row :next_run_at
      row :last_run_at
      row :run_count
      row :max_runs
      row :last_status
      row :last_result do |sc|
        pre JSON.pretty_generate(sc.last_result || {})
      end
      row :created_at
      row :updated_at
    end

    panel "Execution History" do
      table_for scheduled_command.executions.recent.limit(25) do
        column :id
        column :status do |e|
          color = case e.status
                  when 'success' then 'green'
                  when 'failed' then 'red'
                  when 'timeout' then 'orange'
                  else 'grey'
                  end
          status_tag e.status, class: color
        end
        column :executed_at
        column :duration_ms do |e|
          e.duration_ms ? "#{e.duration_ms}ms" : '-'
        end
        column :result do |e|
          pre JSON.pretty_generate(e.result || {})
        end
      end
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs "Scheduled Command" do
      f.input :name
      f.input :description
      f.input :smartphone, as: :select, collection: Smartphone.all.map { |s| ["#{s.name} (#{s.device_id})", s.id] }
      f.input :command, as: :select, collection: CommandSender::ALLOWED_COMMANDS
      f.input :schedule_type, as: :select, collection: ScheduledCommand.schedule_types.keys
      f.input :cron_expression, hint: 'Format: minute hour day month weekday (e.g., "*/30 * * * *" for every 30 min)'
      f.input :next_run_at, as: :datepicker
      f.input :active
      f.input :max_runs, hint: 'Leave blank for unlimited'
    end
    f.actions
  end

  member_action :toggle, method: :post do
    resource.update!(active: !resource.active?)
    if resource.active? && resource.recurring?
      next_run = CommandSchedulerService.next_run_time(resource.cron_expression)
      resource.update_column(:next_run_at, next_run)
    end
    redirect_to admin_scheduled_command_path(resource),
                notice: resource.active? ? 'Schedule activated' : 'Schedule deactivated'
  end
end
