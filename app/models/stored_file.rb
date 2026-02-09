class StoredFile < ApplicationRecord
  validates :path, :original_filename, :checksum, :storage_key, :storage_backend, presence: true
  validates :storage_key, uniqueness: true
  validates :size, numericality: { greater_than_or_equal_to: 0 }
  validates :reference_count, numericality: { greater_than_or_equal_to: 0 }
  validates :storage_backend, inclusion: { in: %w[local s3] }

  scope :by_backend, ->(backend) { where(storage_backend: backend) }
  scope :orphaned, -> { where('reference_count <= 0') }
  scope :older_than, ->(date) { where('created_at < ?', date) }
  scope :duplicates, -> { where('reference_count > 1') }
end
