class RemoveCreatedAtUpdatedAtFromVideos < ActiveRecord::Migration[6.0]
  def change

    remove_column :videos, :created_at, :datetime

    remove_column :videos, :updated_at, :datetime
  end
end
