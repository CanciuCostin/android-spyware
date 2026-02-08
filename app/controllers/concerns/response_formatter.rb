module ResponseFormatter
  extend ActiveSupport::Concern
  
  def render_success(data, options = {})
    response = {
      status: 'success',
      data: serialize_data(data, options),
      message: options[:message]
    }.compact
    
    render json: response, status: options[:status] || :ok
  end
  
  def render_accepted(data, options = {})
    render_success(data, options.merge(status: :accepted))
  end
  
  def render_created(data, options = {})
    render_success(data, options.merge(status: :created))
  end
  
  def render_error(message, options = {})
    response = {
      status: 'error',
      error: {
        message: message,
        details: options[:details],
        code: options[:code]
      }.compact
    }
    
    render json: response, status: options[:status] || :bad_request
  end
  
  def render_not_found(message = 'Resource not found')
    render_error(message, status: :not_found, code: 'NOT_FOUND')
  end
  
  def render_unauthorized(message = 'Unauthorized')
    render_error(message, status: :unauthorized, code: 'UNAUTHORIZED')
  end
  
  def render_forbidden(message = 'Forbidden')
    render_error(message, status: :forbidden, code: 'FORBIDDEN')
  end
  
  private
  
  def serialize_data(data, options)
    return data if options[:raw]
    
    if options[:serializer]
      if data.respond_to?(:map)
        data.map { |item| options[:serializer].new(item, options).as_json }
      else
        options[:serializer].new(data, options).as_json
      end
    else
      data
    end
  end
end
