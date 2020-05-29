class RemoveSourceDestinationContentFromSmsMessages < ActiveRecord::Migration[6.0]
  def change

    remove_column :sms_messages, :source, :string

    remove_column :sms_messages, :destination, :string

    remove_column :sms_messages, :content, :string
  end
end
