class RemoveCreatedAtUpdatedAtFromPictures < ActiveRecord::Migration[6.0]
  def change

    remove_column :pictures, :created_at, :datetime

    remove_column :pictures, :updated_at, :datetime
  end
end
