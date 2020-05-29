class AddFilenameDateToContacts < ActiveRecord::Migration[6.0]
  def change
    add_column :contacts, :filename, :string
    add_column :contacts, :date, :string
  end
end
