class CreateErrorTracking < ActiveRecord::Migration[6.0]
  def change
    create_table :tracked_errors do |t|
      t.string :fingerprint, null: false
      t.string :error_class, null: false
      t.text :message, null: false
      t.json :backtrace, default: []
      t.integer :count, null: false, default: 0
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.string :status, null: false, default: 'open'
      t.json :device_ids, default: []
      t.datetime :resolved_at
      t.timestamps

      t.index :fingerprint, unique: true
      t.index :status
      t.index :last_seen_at
      t.index :count
      t.index [:status, :last_seen_at], name: 'index_tracked_errors_on_status_and_last_seen'
    end
  end
end
