module Storage
  class LocalAdapter
    def initialize
      @root = Rails.application.config.x.storage.local_root
      FileUtils.mkdir_p(@root)
    end

    def upload(key, file_or_path, metadata: {})
      dest = full_path(key)
      FileUtils.mkdir_p(File.dirname(dest))

      if file_or_path.respond_to?(:read)
        File.open(dest, 'wb') { |f| IO.copy_stream(file_or_path, f) }
      else
        FileUtils.cp(file_or_path.to_s, dest)
      end

      write_metadata(key, metadata) if metadata.any?
      { key: key, size: File.size(dest), backend: 'local' }
    end

    def download(key)
      path = full_path(key)
      raise StorageService::FileNotFound, "File not found: #{key}" unless File.exist?(path)

      path
    end

    def delete(key)
      path = full_path(key)
      File.delete(path) if File.exist?(path)
      delete_metadata(key)
      true
    end

    def exists?(key)
      File.exist?(full_path(key))
    end

    def list(prefix: nil)
      pattern = prefix ? File.join(@root, prefix, '**', '*') : File.join(@root, '**', '*')
      Dir.glob(pattern).select { |f| File.file?(f) && !f.end_with?('.meta.json') }.map do |f|
        relative_path(f)
      end
    end

    def signed_url(key, expires_in: nil)
      path = full_path(key)
      raise StorageService::FileNotFound, "File not found: #{key}" unless File.exist?(path)

      # Local adapter returns the file path directly
      path.to_s
    end

    def file_size(key)
      path = full_path(key)
      raise StorageService::FileNotFound, "File not found: #{key}" unless File.exist?(path)

      File.size(path)
    end

    def disk_usage
      total = 0
      Dir.glob(File.join(@root, '**', '*')).each do |f|
        total += File.size(f) if File.file?(f)
      end
      total
    end

    private

    def full_path(key)
      path = File.expand_path(File.join(@root, key))
      unless path.start_with?(File.expand_path(@root))
        raise SecurityError, "Path traversal detected"
      end
      path
    end

    def relative_path(absolute)
      expanded_root = File.expand_path(@root)
      absolute.sub("#{expanded_root}/", '').sub("#{expanded_root}\\", '')
    end

    def metadata_path(key)
      "#{full_path(key)}.meta.json"
    end

    def write_metadata(key, metadata)
      File.write(metadata_path(key), JSON.generate(metadata))
    end

    def delete_metadata(key)
      meta = metadata_path(key)
      File.delete(meta) if File.exist?(meta)
    end
  end
end
