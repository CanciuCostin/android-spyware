class AddStatusToApkPayloads < ActiveRecord::Migration[6.0]
  def change
    add_column :apk_payloads, :status, :string, default: 'pending'
  end
end
