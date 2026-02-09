class AddCapturedAtToKeylogs < ActiveRecord::Migration[6.0]
  def change
    add_column :keylogs, :captured_at, :datetime unless column_exists?(:keylogs, :captured_at)
  end
end
