-- Migration: CreatePendingCommands
-- Run with: bundle exec rails runner "ActiveRecord::Base.connection.execute(File.read('db/manual_migration_pending_commands.sql'))"

CREATE TABLE IF NOT EXISTS pending_commands (
  id SERIAL PRIMARY KEY,
  smartphone_id INTEGER NOT NULL REFERENCES smartphones(id),
  request_id VARCHAR(255) NOT NULL UNIQUE,
  command VARCHAR(255) NOT NULL,
  params JSON,
  status INTEGER DEFAULT 0 NOT NULL,
  response_data JSON,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS index_pending_commands_on_smartphone_id ON pending_commands(smartphone_id);
CREATE INDEX IF NOT EXISTS index_pending_commands_on_request_id ON pending_commands(request_id);
CREATE INDEX IF NOT EXISTS index_pending_commands_on_status ON pending_commands(status);
CREATE INDEX IF NOT EXISTS index_pending_commands_on_created_at ON pending_commands(created_at);
