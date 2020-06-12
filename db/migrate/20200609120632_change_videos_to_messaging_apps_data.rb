class ChangeVideosToMessagingAppsData < ActiveRecord::Migration[6.0]
  def change
    rename_table :videos, :messaging_apps_data
  end
end
