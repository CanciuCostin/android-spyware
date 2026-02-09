module Types
  class QueryType < Types::BaseObject
    field :devices, [Types::DeviceType], null: false
    field :command_queue, [Types::CommandType], null: false
    field :webrtc_status, [Types::WebrtcStatusType], null: false

    def devices
      DeviceCommandService.devices_snapshot
    end

    def command_queue
      DeviceCommandService.command_queue
    end

    def webrtc_status
      DeviceCommandService.webrtc_status
    end
  end
end
