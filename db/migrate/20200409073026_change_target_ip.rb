class ChangeTargetIp < ActiveRecord::Migration[6.0]
  def change
       rename_column :apk_installations, :taget_ip, :target_ip
  end
end
