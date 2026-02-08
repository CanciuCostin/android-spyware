# frozen_string_literal: true

class CreateAudioIntelligence < ActiveRecord::Migration[6.0]
  def change
    create_table :audio_transcriptions do |t|
      t.references :recording, null: false, foreign_key: true, index: true
      t.text :text, null: false
      t.string :language, default: 'en'
      t.float :confidence
      t.jsonb :speakers, default: []
      t.jsonb :keywords, default: []
      t.timestamps
    end

    add_index :audio_transcriptions, :language
    add_index :audio_transcriptions, :created_at
  end
end
