class CreatePendingCommands < ActiveRecord::Migration[6.0]
  def change
    create_table :pending_commands do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :request_id, null: false
      t.string :command, null: false
      t.json :params
      t.integer :status, default: 0, null: false
      t.json :response_data
      t.datetime :completed_at
      
      t.timestamps
    end
    
    add_index :pending_commands, :request_id, unique: true
    add_index :pending_commands, :status
    add_index :pending_commands, :created_at
  end
end
