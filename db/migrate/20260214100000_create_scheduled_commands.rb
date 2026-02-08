# frozen_string_literal: true

class CreateScheduledCommands < ActiveRecord::Migration[6.0]
  def change
    create_table :scheduled_commands do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :command, null: false
      t.jsonb :params, default: {}
      t.integer :schedule_type, default: 0, null: false # enum: once=0, recurring=1
      t.string :cron_expression
      t.datetime :next_run_at
      t.datetime :last_run_at
      t.boolean :active, default: true, null: false
      t.integer :run_count, default: 0, null: false
      t.integer :max_runs # nil = unlimited
      t.string :name
      t.text :description
      t.jsonb :last_result
      t.string :last_status # success, failed, timeout

      t.timestamps
    end

    add_index :scheduled_commands, :next_run_at
    add_index :scheduled_commands, :active
    add_index :scheduled_commands, [:active, :next_run_at], name: 'index_scheduled_commands_due'
    add_index :scheduled_commands, :schedule_type

    create_table :scheduled_command_executions do |t|
      t.references :scheduled_command, null: false, foreign_key: true
      t.references :pending_command, foreign_key: true
      t.string :status, null: false # queued, success, failed, timeout
      t.jsonb :result
      t.datetime :executed_at, null: false
      t.integer :duration_ms

      t.timestamps
    end

    add_index :scheduled_command_executions, :executed_at
    add_index :scheduled_command_executions, :status
  end
end
