class AddCToApkPayloads < ActiveRecord::Migration[6.0]
  def change
    add_column :apk_payloads, :name, :string
  end
end
