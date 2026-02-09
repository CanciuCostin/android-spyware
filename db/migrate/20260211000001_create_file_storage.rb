class CreateFileStorage < ActiveRecord::Migration[6.0]
  def change
    create_table :stored_files do |t|
      t.string :path, null: false
      t.string :original_filename, null: false
      t.bigint :size, null: false, default: 0
      t.string :content_type
      t.string :checksum, null: false
      t.string :storage_backend, null: false, default: 'local'
      t.string :storage_key, null: false
      t.integer :reference_count, null: false, default: 1
      t.json :metadata, default: {}
      t.datetime :last_accessed_at
      t.timestamps

      t.index :checksum
      t.index :storage_key, unique: true
      t.index :storage_backend
      t.index :created_at
    end

    create_table :upload_chunks do |t|
      t.string :upload_id, null: false
      t.integer :chunk_number, null: false
      t.integer :total_chunks, null: false
      t.string :checksum
      t.string :filename
      t.string :status, null: false, default: 'pending'
      t.datetime :uploaded_at

      t.index [:upload_id, :chunk_number], unique: true
      t.index :upload_id
      t.index :status
      t.index :uploaded_at
    end
  end
end
