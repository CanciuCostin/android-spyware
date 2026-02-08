# frozen_string_literal: true

# SecurityHeaders middleware adds essential security headers to all HTTP responses
# to protect against common web vulnerabilities (XSS, clickjacking, MIME sniffing, etc.)
class SecurityHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    # Strict Transport Security - force HTTPS for 1 year
    headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
    
    # Prevent clickjacking - deny all framing
    headers['X-Frame-Options'] = 'DENY'
    
    # Prevent MIME type sniffing
    headers['X-Content-Type-Options'] = 'nosniff'
    
    # Enable XSS protection in older browsers
    headers['X-XSS-Protection'] = '1; mode=block'
    
    # Referrer policy - don't leak origin to external sites
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    
    # Permissions policy - disable sensitive features by default
    headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'
    
    # Content Security Policy - defense in depth
    headers['Content-Security-Policy'] = build_csp_policy
    
    [status, headers, response]
  end

  private

  def build_csp_policy
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'", # Needed for ActionCable &amp; legacy JS
      "style-src 'self' 'unsafe-inline'", # Needed for inline styles
      "img-src 'self' data: https:",
      "font-src 'self' data:",
      "connect-src 'self' ws: wss:", # WebSocket support
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'"
    ].join('; ')
  end
end
