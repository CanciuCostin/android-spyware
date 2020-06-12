class ChangeMessagingAppsDataToMessagingAppsDumps < ActiveRecord::Migration[6.0]
  def change
    rename_table :messaging_apps_data, :messaging_apps_dumps
  end
end
