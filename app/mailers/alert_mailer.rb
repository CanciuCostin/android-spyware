class AlertMailer < ApplicationMailer
  def alert_notification(alert, to, from)
    @alert = alert
    @device = alert.device
    
    mail(
      to: to,
      from: from,
      subject: "[#{alert.severity.upcase}] #{alert.title}"
    )
  end
end
