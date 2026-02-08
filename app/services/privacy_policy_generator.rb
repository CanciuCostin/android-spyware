class PrivacyPolicyGenerator < ApplicationService
  POLICY_VERSION = '1.0'.freeze

  def initialize(device: nil, format: :html)
    @device = device
    @format = format.to_sym
  end

  def call
    generate
  end

  def generate
    active_consents = active_consent_types
    policy_content = build_policy(active_consents)

    result = {
      version: POLICY_VERSION,
      generated_at: Time.current.iso8601,
      format: @format,
      active_consents: active_consents,
      content: render_content(policy_content)
    }

    Result.success(result)
  rescue => e
    Rails.logger.error("[PrivacyPolicyGenerator] Generation failed: #{e.message}")
    Result.failure(e.message)
  end

  private

  def active_consent_types
    return DeviceConsent::CONSENT_TYPES unless @device

    @device.device_consents.granted.pluck(:consent_type)
  end

  def build_policy(consents)
    sections = []
    sections << introduction_section
    sections << data_controller_section
    sections << data_collected_section(consents)
    sections << legal_basis_section
    sections << retention_section
    sections << rights_section
    sections << security_section
    sections << contact_section
    sections
  end

  def render_content(sections)
    case @format
    when :html then render_html(sections)
    else render_text(sections)
    end
  end

  def render_html(sections)
    html = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head><meta charset="UTF-8"><title>Privacy Policy</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }
        h1 { color: #333; border-bottom: 2px solid #333; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        ul { padding-left: 20px; }
        .meta { color: #888; font-size: 0.9em; }
      </style>
      </head>
      <body>
      <h1>Privacy Policy</h1>
      <p class="meta">Version #{POLICY_VERSION} &mdash; Generated #{Time.current.strftime('%B %d, %Y')}</p>
    HTML

    sections.each do |section|
      html += "<h2>#{section[:title]}</h2>\n"
      html += "<p>#{section[:body]}</p>\n"
      if section[:items]
        html += "<ul>\n"
        section[:items].each { |item| html += "  <li>#{item}</li>\n" }
        html += "</ul>\n"
      end
    end

    html += "</body></html>"
    html
  end

  def render_text(sections)
    text = "PRIVACY POLICY\nVersion #{POLICY_VERSION} — Generated #{Time.current.strftime('%B %d, %Y')}\n\n"

    sections.each do |section|
      text += "#{section[:title].upcase}\n#{'=' * section[:title].length}\n"
      text += "#{section[:body]}\n"
      section[:items]&.each { |item| text += "  - #{item}\n" }
      text += "\n"
    end

    text
  end

  def introduction_section
    {
      title: 'Introduction',
      body: 'This Privacy Policy describes how personal data is collected, used, and shared ' \
            'when device monitoring software is installed and active. We are committed to ' \
            'protecting personal data in compliance with the General Data Protection Regulation (GDPR).'
    }
  end

  def data_controller_section
    {
      title: 'Data Controller',
      body: "The data controller responsible for your personal data is: " \
            "#{ENV.fetch('DATA_CONTROLLER_NAME', 'System Administrator')} " \
            "(#{ENV.fetch('DATA_CONTROLLER_EMAIL', 'admin@example.com')})."
    }
  end

  def data_collected_section(consents)
    items = consents.map { |c| consent_data_description(c) }
    {
      title: 'Data We Collect',
      body: 'Based on active consent agreements, the following data categories are collected:',
      items: items
    }
  end

  def consent_data_description(consent_type)
    descriptions = {
      'device_monitoring' => 'Device information including model, OS version, and battery status',
      'location_tracking' => 'GPS location data and geofence events',
      'data_collection' => 'General device data including app usage and browser history',
      'microphone_access' => 'Audio recordings from the device microphone',
      'camera_access' => 'Photos captured from the device camera',
      'sms_monitoring' => 'SMS messages sent and received',
      'call_logging' => 'Call history including numbers, duration, and timestamps'
    }
    descriptions.fetch(consent_type, consent_type.humanize)
  end

  def legal_basis_section
    {
      title: 'Legal Basis for Processing',
      body: 'We process personal data based on the following legal grounds:',
      items: [
        'Explicit consent of the data subject (GDPR Art. 6(1)(a))',
        'Legitimate interests pursued by the data controller (GDPR Art. 6(1)(f))',
        'Compliance with legal obligations (GDPR Art. 6(1)(c))'
      ]
    }
  end

  def retention_section
    periods = DataRetentionService::DEFAULT_RETENTION_PERIODS
    items = periods.map { |type, days| "#{type.to_s.humanize}: #{days} days" }
    {
      title: 'Data Retention',
      body: 'Personal data is retained for the following periods, after which it is automatically deleted:',
      items: items
    }
  end

  def rights_section
    {
      title: 'Your Rights Under GDPR',
      body: 'As a data subject, you have the following rights:',
      items: [
        'Right of access - request a copy of your personal data (Art. 15)',
        'Right to rectification - request correction of inaccurate data (Art. 16)',
        'Right to erasure - request deletion of your personal data (Art. 17)',
        'Right to restrict processing - request limitation of data processing (Art. 18)',
        'Right to data portability - receive your data in a machine-readable format (Art. 20)',
        'Right to object - object to processing of your personal data (Art. 21)',
        'Right to lodge a complaint with a supervisory authority (Art. 77)'
      ]
    }
  end

  def security_section
    {
      title: 'Data Security',
      body: 'We implement appropriate technical and organizational measures to protect personal data, ' \
            'including encryption in transit and at rest, access controls, audit logging, and regular security reviews.'
    }
  end

  def contact_section
    {
      title: 'Contact Information',
      body: "For questions about this privacy policy or to exercise your data protection rights, contact: " \
            "#{ENV.fetch('DATA_CONTROLLER_EMAIL', 'admin@example.com')}. " \
            "You may also contact your local data protection authority."
    }
  end
end
