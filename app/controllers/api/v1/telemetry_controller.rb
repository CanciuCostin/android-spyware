module Api
  module V1
    class TelemetryController < ApplicationController
      before_action :authenticate_admin_user!

      def devices
        render json: DeviceCommandService.devices_snapshot
      end

      def command_queue
        render json: DeviceCommandService.command_queue
      end

      def webrtc_status
        render json: DeviceCommandService.webrtc_status
      end

      def uploads
        render json: DeviceCommandService.upload_progress
      end
    end
  end
end
