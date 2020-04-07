class CreateSmartphones < ActiveRecord::Migration[6.0]
  def change
    create_table :smartphones do |t|
      t.string :operating_system
      t.string :name
      t.string :is_rooted
      t.string :is_app_hidden
      t.references :apk_installation, null: false, foreign_key: true

      t.timestamps
    end
  end
end
