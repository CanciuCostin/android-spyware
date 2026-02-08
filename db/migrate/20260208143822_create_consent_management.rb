class CreateConsentManagement < ActiveRecord::Migration[6.0]
  def change
    create_table :device_consents do |t|
      t.references :device, null: false, foreign_key: { to_table: :apk_installations }
      t.string :consent_type, null: false
      t.boolean :granted, default: false, null: false
      t.datetime :granted_at
      t.datetime :revoked_at
      t.string :granted_by
      t.string :ip_address
      t.text :consent_text
      t.string :consent_version
      t.json :metadata, default: {}
      t.timestamps
      
      t.index [:device_id, :consent_type], unique: true
      t.index :granted
      t.index :consent_type
    end
    
    create_table :terms_acceptances do |t|
      t.references :device, null: false, foreign_key: { to_table: :apk_installations }
      t.string :terms_version, null: false
      t.text :terms_text
      t.boolean :accepted, default: false
      t.datetime :accepted_at
      t.string :ip_address
      t.string :user_agent
      t.json :acceptance_metadata, default: {}
      t.timestamps
      
      t.index [:device_id, :terms_version]
      t.index :accepted
    end
    
    create_table :data_usage_disclosures do |t|
      t.references :device, null: false, foreign_key: { to_table: :apk_installations }
      t.string :disclosure_type
      t.text :disclosure_content
      t.datetime :disclosed_at
      t.boolean :acknowledged, default: false
      t.datetime :acknowledged_at
      t.timestamps
      
      t.index :device_id
      t.index :disclosure_type
    end
  end
end
