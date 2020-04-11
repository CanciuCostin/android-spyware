class RemoveCreatedAtUpdatedAtFromApkInstallations < ActiveRecord::Migration[6.0]
  def change

    remove_column :apk_installations, :created_at, :datetime

    remove_column :apk_installations, :updated_at, :datetime
  end
end
