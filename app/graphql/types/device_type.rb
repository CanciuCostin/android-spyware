module Types
  class DeviceType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true
    field :device_id, String, null: true
    field :operating_system, String, null: true
    field :status, String, null: true
    field :pending, Integer, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :last_command_summary, Types::CommandSummaryType, null: true, method: :last_command
  end
end
