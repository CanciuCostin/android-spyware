# frozen_string_literal: true

class CreateDataCollection < ActiveRecord::Migration[6.0]
  def change
    create_table :bookmarks do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :title
      t.string :url, null: false
      t.string :browser
      t.string :folder
      t.datetime :bookmarked_at

      t.timestamps
    end

    add_index :bookmarks, [:smartphone_id, :url]
    add_index :bookmarks, :browser

    create_table :certificates do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :subject, null: false
      t.string :issuer
      t.string :serial_number
      t.string :fingerprint_sha256
      t.datetime :valid_from
      t.datetime :valid_to
      t.boolean :is_system, default: false, null: false
      t.boolean :is_trusted, default: true, null: false

      t.timestamps
    end

    add_index :certificates, [:smartphone_id, :fingerprint_sha256]
    add_index :certificates, :is_system

    create_table :wifi_networks do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.string :ssid, null: false
      t.string :bssid
      t.string :security_type
      t.integer :signal_strength
      t.boolean :is_connected, default: false, null: false
      t.boolean :is_saved, default: false, null: false
      t.datetime :first_seen_at
      t.datetime :last_connected_at

      t.timestamps
    end

    add_index :wifi_networks, [:smartphone_id, :ssid]
    add_index :wifi_networks, :is_connected

    create_table :clipboard_entries do |t|
      t.references :smartphone, null: false, foreign_key: true
      t.text :content, null: false
      t.string :source_app
      t.datetime :captured_at, null: false

      t.timestamps
    end

    add_index :clipboard_entries, [:smartphone_id, :captured_at]
    add_index :clipboard_entries, :source_app
  end
end
