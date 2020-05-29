class RemoveSourceDestinationDurationFromCallLogs < ActiveRecord::Migration[6.0]
  def change

    remove_column :call_logs, :source, :string

    remove_column :call_logs, :destination, :string

    remove_column :call_logs, :duration, :string
  end
end
