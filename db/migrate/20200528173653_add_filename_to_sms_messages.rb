class AddFilenameToSmsMessages < ActiveRecord::Migration[6.0]
  def change
    add_column :sms_messages, :filename, :string
  end
end
