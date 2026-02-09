class UploadChunk < ApplicationRecord
  validates :upload_id, :chunk_number, :total_chunks, :status, presence: true
  validates :chunk_number, uniqueness: { scope: :upload_id }
  validates :status, inclusion: { in: %w[pending uploaded verified failed] }

  scope :for_upload, ->(upload_id) { where(upload_id: upload_id) }
  scope :completed, -> { where(status: 'uploaded') }
  scope :stale, -> { where('uploaded_at < ?', 24.hours.ago) }
end
