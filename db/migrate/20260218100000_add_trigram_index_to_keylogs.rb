class AddTrigramIndexToKeylogs < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    add_index :keylogs, :keystroke, using: :gin, opclass: :gin_trgm_ops,
              name: 'index_keylogs_on_keystroke_trgm', algorithm: :concurrently
    add_index :keylogs, :full_text, using: :gin, opclass: :gin_trgm_ops,
              name: 'index_keylogs_on_full_text_trgm', algorithm: :concurrently
    add_index :keylogs, :app_name, using: :gin, opclass: :gin_trgm_ops,
              name: 'index_keylogs_on_app_name_trgm', algorithm: :concurrently
  end

  def down
    remove_index :keylogs, name: 'index_keylogs_on_keystroke_trgm'
    remove_index :keylogs, name: 'index_keylogs_on_full_text_trgm'
    remove_index :keylogs, name: 'index_keylogs_on_app_name_trgm'
    disable_extension 'pg_trgm'
  end
end
