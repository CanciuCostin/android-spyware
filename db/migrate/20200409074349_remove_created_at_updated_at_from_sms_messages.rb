class RemoveCreatedAtUpdatedAtFromSmsMessages < ActiveRecord::Migration[6.0]
  def change

    remove_column :sms_messages, :created_at, :datetime

    remove_column :sms_messages, :updated_at, :datetime
  end
end
