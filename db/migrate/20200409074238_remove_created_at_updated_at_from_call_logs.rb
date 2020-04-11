class RemoveCreatedAtUpdatedAtFromCallLogs < ActiveRecord::Migration[6.0]
  def change

    remove_column :call_logs, :created_at, :datetime

    remove_column :call_logs, :updated_at, :datetime
  end
end
