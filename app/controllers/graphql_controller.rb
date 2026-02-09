class GraphqlController < ApplicationController
  before_action :authenticate_admin_user!

  def execute
    variables = ensure_hash(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]

    result = EagleSpySchema.execute(
      query,
      variables: variables,
      context: { current_admin_user: current_admin_user },
      operation_name: operation_name
    )

    render json: result
  rescue StandardError => e
    Rails.logger.error("[GraphQL] #{e.message}")
    render json: { errors: [{ message: e.message }] }, status: :internal_server_error
  end

  private

  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      ambiguous_param.present? ? JSON.parse(ambiguous_param) : {}
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param.class}"
    end
  end
end
