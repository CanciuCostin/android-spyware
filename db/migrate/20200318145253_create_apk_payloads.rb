class CreateApkPayloads < ActiveRecord::Migration[6.0]
  def change
    create_table :apk_payloads do |t|
      t.string :destination_ip
      t.string :destination_port
      t.string :forwarding_ip
      t.string :forwarding_port

      t.timestamps
    end
  end
end
