class RemoveCreatedAtUpdatedAtFromScreenshots < ActiveRecord::Migration[6.0]
  def change

    remove_column :screenshots, :created_at, :datetime

    remove_column :screenshots, :updated_at, :datetime
  end
end
