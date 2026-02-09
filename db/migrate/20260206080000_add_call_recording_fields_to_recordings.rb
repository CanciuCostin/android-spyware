class AddCallRecordingFieldsToRecordings < ActiveRecord::Migration[6.0]
  def change
    add_column :recordings, :recording_type, :string, default: 'audio'
    add_column :recordings, :call_number, :string
    add_column :recordings, :call_direction, :string
    add_column :recordings, :strategy, :string

    add_index :recordings, :recording_type
  end
end
