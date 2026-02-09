class DeduplicationService < ApplicationService
  def call
    deduplicate_files
  end

  # Find and deduplicate files with identical content
  def deduplicate_files
    duplicates = find_duplicates
    saved_bytes = 0
    deduped_count = 0

    duplicates.each do |checksum, files|
      primary = files.first
      files[1..].each do |duplicate|
        saved = link_duplicate(primary, duplicate)
        if saved
          saved_bytes += saved
          deduped_count += 1
        end
      end
    end

    Result.success(
      deduplicated: deduped_count,
      saved_bytes: saved_bytes,
      saved_human: human_size(saved_bytes)
    )
  rescue => e
    Rails.logger.error("DeduplicationService failed: #{e.message}")
    Result.failure(e.message)
  end

  # Report on potential storage savings from deduplication
  def self.report
    groups = StoredFile.group(:checksum).having('COUNT(*) > 1').count
    total_wasted = 0

    groups.each do |checksum, count|
      file = StoredFile.find_by(checksum: checksum)
      total_wasted += file.size * (count - 1) if file
    end

    {
      duplicate_groups: groups.size,
      total_duplicate_files: groups.values.sum - groups.size,
      wasted_bytes: total_wasted,
      wasted_human: human_size(total_wasted)
    }
  end

  private

  def find_duplicates
    grouped = StoredFile.group(:checksum).having('COUNT(*) > 1').pluck(:checksum)
    result = {}

    grouped.each do |checksum|
      result[checksum] = StoredFile.where(checksum: checksum).order(:created_at).to_a
    end

    result
  end

  def link_duplicate(primary, duplicate)
    return nil if primary.storage_backend != 'local' || duplicate.storage_backend != 'local'

    storage = StorageService.new(backend: 'local')
    primary_path = storage.download(primary.storage_key)
    return nil unless primary_path.success?

    dup_path_result = storage.download(duplicate.storage_key)
    return nil unless dup_path_result.success?

    dup_full_path = dup_path_result.value[:path]
    saved = duplicate.size

    # Remove the duplicate physical file
    File.delete(dup_full_path) if File.exist?(dup_full_path)

    # Create a hard link (or symlink on Windows)
    primary_full_path = primary_path.value[:path]
    begin
      FileUtils.ln(primary_full_path, dup_full_path)
    rescue Errno::EXDEV, NotImplementedError
      # Cross-device or unsupported: use symlink
      FileUtils.ln_s(primary_full_path, dup_full_path)
    end

    # Update reference counts
    primary.increment!(:reference_count)
    duplicate.update!(reference_count: 0)

    Rails.logger.info("Deduplicated: #{duplicate.storage_key} -> #{primary.storage_key}")
    saved
  rescue => e
    Rails.logger.warn("Failed to deduplicate #{duplicate&.storage_key}: #{e.message}")
    nil
  end

  def human_size(bytes)
    self.class.human_size(bytes)
  end

  def self.human_size(bytes)
    return '0 B' if bytes == 0
    units = %w[B KB MB GB TB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.size - 1 if exp >= units.size
    "%.1f %s" % [bytes.to_f / (1024**exp), units[exp]]
  end
end
