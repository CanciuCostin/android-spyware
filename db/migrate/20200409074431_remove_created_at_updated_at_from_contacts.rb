class RemoveCreatedAtUpdatedAtFromContacts < ActiveRecord::Migration[6.0]
  def change

    remove_column :contacts, :created_at, :datetime

    remove_column :contacts, :updated_at, :datetime
  end
end
