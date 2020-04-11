class RemoveCreatedAtUpdatedAtFromRecordings < ActiveRecord::Migration[6.0]
  def change

    remove_column :recordings, :created_at, :datetime

    remove_column :recordings, :updated_at, :datetime
  end
end
