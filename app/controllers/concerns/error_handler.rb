module ErrorHandler
  extend ActiveSupport::Concern
  
  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ArgumentError, with: :handle_argument_error
    rescue_from SecurityError, with: :handle_security_error
  end
  
  private
  
  def handle_standard_error(exception)
    Rails.logger.error("#{exception.class}: #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))
    
    render_error(
      'An unexpected error occurred',
      status: :internal_server_error,
      details: Rails.env.development? ? exception.message : nil
    )
  end
  
  def handle_not_found(exception)
    render_not_found(exception.message)
  end
  
  def handle_invalid_record(exception)
    render_error(
      exception.record.errors.full_messages.join(', '),
      status: :unprocessable_entity
    )
  end
  
  def handle_parameter_missing(exception)
    render_error(
      "Missing parameter: #{exception.param}",
      status: :bad_request
    )
  end
  
  def handle_argument_error(exception)
    render_error(
      exception.message,
      status: :bad_request
    )
  end
  
  def handle_security_error(exception)
    Rails.logger.warn("Security error: #{exception.message}")
    render_error(
      'Security validation failed',
      status: :forbidden,
      details: Rails.env.development? ? exception.message : nil
    )
  end
end
