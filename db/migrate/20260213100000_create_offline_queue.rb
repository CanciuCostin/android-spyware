# frozen_string_literal: true

class CreateOfflineQueue < ActiveRecord::Migration[6.0]
  def change
    create_table :queued_commands do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :command, null: false
      t.jsonb :params, default: {}
      t.integer :priority, default: 5, null: false
      t.datetime :expires_at, null: false
      t.string :status, default: 'pending', null: false
      t.datetime :sent_at
      t.string :error_message

      t.timestamps
    end

    add_index :queued_commands, [:smartphone_id, :status]
    add_index :queued_commands, [:status, :expires_at]
    add_index :queued_commands, [:smartphone_id, :priority, :created_at],
              name: 'index_queued_commands_on_device_priority_order'
  end
end
