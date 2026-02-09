class CreateUserPreferences < ActiveRecord::Migration[6.0]
  def change
    create_table :user_preferences do |t|
      t.references :admin_user, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :preferences, null: false, default: {}
      t.timestamps
    end
  end
end
