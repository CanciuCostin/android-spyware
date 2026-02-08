# frozen_string_literal: true

module Api
  class ScheduledCommandsController < BaseController
    before_action :set_smartphone
    before_action :set_scheduled_command, only: [:show, :update, :destroy, :toggle, :executions]

    # GET /api/devices/:device_id/scheduled_commands
    def index
      commands = @smartphone.scheduled_commands.by_next_run
      commands = commands.active if params[:active_only] == 'true'
      commands = commands.where(schedule_type: params[:schedule_type]) if params[:schedule_type].present?

      render json: {
        scheduled_commands: commands.map { |c| serialize_command(c) },
        total: commands.count
      }
    end

    # GET /api/devices/:device_id/scheduled_commands/:id
    def show
      render json: {
        scheduled_command: serialize_command(@scheduled_command),
        recent_executions: @scheduled_command.executions.recent.limit(10).map { |e| serialize_execution(e) }
      }
    end

    # POST /api/devices/:device_id/scheduled_commands
    def create
      scheduled = @smartphone.scheduled_commands.build(scheduled_command_params)

      if scheduled.recurring? && scheduled.cron_expression.present?
        unless CommandSchedulerService.valid_cron?(scheduled.cron_expression)
          return render json: { error: 'Invalid cron expression' }, status: :unprocessable_entity
        end

        scheduled.next_run_at ||= CommandSchedulerService.next_run_time(scheduled.cron_expression)
      end

      if scheduled.save
        render json: { scheduled_command: serialize_command(scheduled) }, status: :created
      else
        render json: { errors: scheduled.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /api/devices/:device_id/scheduled_commands/:id
    def update
      if @scheduled_command.update(scheduled_command_params)
        # Recalculate next_run_at if cron changed
        if @scheduled_command.recurring? && @scheduled_command.saved_change_to_cron_expression?
          next_run = CommandSchedulerService.next_run_time(@scheduled_command.cron_expression)
          @scheduled_command.update_column(:next_run_at, next_run)
        end

        render json: { scheduled_command: serialize_command(@scheduled_command) }
      else
        render json: { errors: @scheduled_command.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/devices/:device_id/scheduled_commands/:id
    def destroy
      @scheduled_command.destroy
      render json: { message: 'Scheduled command deleted' }
    end

    # POST /api/devices/:device_id/scheduled_commands/:id/toggle
    def toggle
      @scheduled_command.update!(active: !@scheduled_command.active?)

      # Recalculate next run if re-activating a recurring command
      if @scheduled_command.active? && @scheduled_command.recurring?
        next_run = CommandSchedulerService.next_run_time(@scheduled_command.cron_expression)
        @scheduled_command.update_column(:next_run_at, next_run)
      end

      render json: {
        scheduled_command: serialize_command(@scheduled_command),
        message: @scheduled_command.active? ? 'Schedule activated' : 'Schedule deactivated'
      }
    end

    # GET /api/devices/:device_id/scheduled_commands/:id/executions
    def executions
      page = (params[:page] || 1).to_i
      per_page = [(params[:per_page] || 20).to_i, 100].min
      execs = @scheduled_command.executions.recent.offset((page - 1) * per_page).limit(per_page)

      render json: {
        executions: execs.map { |e| serialize_execution(e) },
        total: @scheduled_command.executions.count,
        page: page,
        per_page: per_page
      }
    end

    private

    def set_smartphone
      device_id = sanitize_device_id(params[:device_id])
      @smartphone = Smartphone.find_by!(device_id: device_id)
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Device not found' }, status: :not_found
    end

    def set_scheduled_command
      @scheduled_command = @smartphone.scheduled_commands.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Scheduled command not found' }, status: :not_found
    end

    def scheduled_command_params
      params.require(:scheduled_command).permit(
        :command, :schedule_type, :cron_expression,
        :next_run_at, :active, :max_runs, :name, :description,
        params: {}
      )
    end

    def serialize_command(cmd)
      {
        id: cmd.id,
        name: cmd.name,
        description: cmd.description,
        command: cmd.command,
        params: cmd.params,
        schedule_type: cmd.schedule_type,
        cron_expression: cmd.cron_expression,
        next_run_at: cmd.next_run_at&.iso8601,
        last_run_at: cmd.last_run_at&.iso8601,
        active: cmd.active?,
        run_count: cmd.run_count,
        max_runs: cmd.max_runs,
        last_status: cmd.last_status,
        last_result: cmd.last_result,
        created_at: cmd.created_at.iso8601,
        updated_at: cmd.updated_at.iso8601
      }
    end

    def serialize_execution(exec)
      {
        id: exec.id,
        status: exec.status,
        result: exec.result,
        executed_at: exec.executed_at.iso8601,
        duration_ms: exec.duration_ms,
        pending_command_id: exec.pending_command_id
      }
    end
  end
end
