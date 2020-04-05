class CreateApkInstallations < ActiveRecord::Migration[6.0]
  def change
    create_table :apk_installations do |t|
      t.string :taget_ip
      t.string :status
      t.references :apk_payload, null: false, foreign_key: true

      t.timestamps
    end
  end
end
