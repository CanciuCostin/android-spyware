module Types
  class WebrtcStatusType < Types::BaseObject
    field :request_id, String, null: false
    field :command, String, null: false
    field :status, String, null: false
    field :device_id, String, null: true
    field :issued_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
