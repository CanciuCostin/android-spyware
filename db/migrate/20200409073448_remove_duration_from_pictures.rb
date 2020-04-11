class RemoveDurationFromPictures < ActiveRecord::Migration[6.0]
  def change

    remove_column :pictures, :duration, :string
  end
end
