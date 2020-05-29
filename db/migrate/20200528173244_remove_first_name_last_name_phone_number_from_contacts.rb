class RemoveFirstNameLastNamePhoneNumberFromContacts < ActiveRecord::Migration[6.0]
  def change

    remove_column :contacts, :first_name, :string

    remove_column :contacts, :last_name, :string

    remove_column :contacts, :phone_number, :string
  end
end
