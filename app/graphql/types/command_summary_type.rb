module Types
  class CommandSummaryType < Types::BaseObject
    field :command, String, null: true
    field :status, String, null: true
    field :issued_at, GraphQL::Types::ISO8601DateTime, null: true
  end
end
