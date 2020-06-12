class AddAppNameToMessagingAppsDumps < ActiveRecord::Migration[6.0]
  def change
    add_column :messaging_apps_dumps, :app_name, :string
  end
end
