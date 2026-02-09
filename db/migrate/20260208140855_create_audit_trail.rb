class CreateAuditTrail < ActiveRecord::Migration[6.0]
  def change
    create_table :audit_logs do |t|
      t.references :admin_user, foreign_key: true
      t.string :action, null: false # 'create', 'update', 'delete', 'read'
      t.string :auditable_type # Model name
      t.bigint :auditable_id
      t.json :changes, default: {} # Before/after values
      t.json :metadata, default: {} # IP, user agent, etc.
      t.string :ip_address
      t.string :user_agent
      t.text :request_params
      t.string :request_method
      t.string :request_path
      t.integer :response_status
      t.timestamps
      
      # Immutability - no updates allowed
      t.index :created_at
      t.index [:admin_user_id, :created_at]
      t.index [:auditable_type, :auditable_id]
      t.index :action
    end
    
    # Add trigger to prevent updates/deletes
    execute <<-SQL
      CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
      RETURNS TRIGGER AS $$
      BEGIN
        IF (TG_OP = 'UPDATE' OR TG_OP = 'DELETE') THEN
          RAISE EXCEPTION 'Audit logs are immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
      
      CREATE TRIGGER audit_log_immutable
      BEFORE UPDATE OR DELETE ON audit_logs
      FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_modification();
    SQL
  end
  
  def down
    execute "DROP TRIGGER IF EXISTS audit_log_immutable ON audit_logs"
    execute "DROP FUNCTION IF EXISTS prevent_audit_log_modification"
    drop_table :audit_logs
  end
end
