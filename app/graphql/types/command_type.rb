module Types
  class CommandType < Types::BaseObject
    field :request_id, String, null: false
    field :command, String, null: false
    field :status, String, null: false
    field :params, GraphQL::Types::JSON, null: true
    field :device_id, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
