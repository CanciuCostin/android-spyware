module Storage
  class S3Adapter
    MULTIPART_THRESHOLD = 100.megabytes
    PART_SIZE = 5.megabytes

    def initialize
      @bucket_name = Rails.application.config.x.storage.s3_bucket
      @region = Rails.application.config.x.storage.s3_region

      unless defined?(Aws::S3::Client)
        raise StorageService::ConfigError, "aws-sdk-s3 gem is not available. Add it to your Gemfile."
      end

      client_opts = {
        region: @region,
        access_key_id: Rails.application.config.x.storage.s3_access_key_id,
        secret_access_key: Rails.application.config.x.storage.s3_secret_access_key
      }

      endpoint = Rails.application.config.x.storage.s3_endpoint
      if endpoint.present?
        client_opts[:endpoint] = endpoint
        client_opts[:force_path_style] = true
      end

      @client = Aws::S3::Client.new(client_opts)
      @resource = Aws::S3::Resource.new(client: @client)
      @bucket = @resource.bucket(@bucket_name)
    end

    def upload(key, file_or_path, metadata: {})
      body, size = resolve_body(file_or_path)

      if size && size > MULTIPART_THRESHOLD
        multipart_upload(key, file_or_path, metadata)
      else
        @client.put_object(
          bucket: @bucket_name,
          key: key,
          body: body,
          server_side_encryption: 'AES256',
          metadata: metadata.transform_values(&:to_s)
        )
      end

      { key: key, size: size || file_size(key), backend: 's3' }
    end

    def download(key)
      raise StorageService::FileNotFound, "File not found: #{key}" unless exists?(key)

      temp = Tempfile.new(['s3_download', File.extname(key)])
      @client.get_object(bucket: @bucket_name, key: key, response_target: temp.path)
      temp.path
    end

    def delete(key)
      @client.delete_object(bucket: @bucket_name, key: key)
      true
    end

    def exists?(key)
      @client.head_object(bucket: @bucket_name, key: key)
      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      false
    end

    def list(prefix: nil)
      opts = { bucket: @bucket_name }
      opts[:prefix] = prefix if prefix

      keys = []
      @client.list_objects_v2(opts).each do |response|
        response.contents.each { |obj| keys << obj.key }
      end
      keys
    end

    def signed_url(key, expires_in: nil)
      expires_in ||= Rails.application.config.x.storage.signed_url_expiry
      signer = Aws::S3::Presigner.new(client: @client)
      signer.presigned_url(:get_object, bucket: @bucket_name, key: key, expires_in: expires_in)
    end

    def file_size(key)
      resp = @client.head_object(bucket: @bucket_name, key: key)
      resp.content_length
    rescue Aws::S3::Errors::NotFound
      raise StorageService::FileNotFound, "File not found: #{key}"
    end

    def disk_usage
      total = 0
      @client.list_objects_v2(bucket: @bucket_name).each do |response|
        response.contents.each { |obj| total += obj.size }
      end
      total
    end

    private

    def resolve_body(file_or_path)
      if file_or_path.respond_to?(:read)
        content = file_or_path.read
        file_or_path.rewind if file_or_path.respond_to?(:rewind)
        [content, content.bytesize]
      elsif File.exist?(file_or_path.to_s)
        [File.open(file_or_path.to_s, 'rb'), File.size(file_or_path.to_s)]
      else
        raise ArgumentError, "Invalid file source"
      end
    end

    def multipart_upload(key, file_or_path, metadata)
      resp = @client.create_multipart_upload(
        bucket: @bucket_name,
        key: key,
        server_side_encryption: 'AES256',
        metadata: metadata.transform_values(&:to_s)
      )
      upload_id = resp.upload_id

      parts = []
      part_number = 1
      io = file_or_path.respond_to?(:read) ? file_or_path : File.open(file_or_path.to_s, 'rb')

      begin
        while (chunk = io.read(PART_SIZE))
          resp = @client.upload_part(
            bucket: @bucket_name,
            key: key,
            upload_id: upload_id,
            part_number: part_number,
            body: chunk
          )
          parts << { etag: resp.etag, part_number: part_number }
          part_number += 1
        end

        @client.complete_multipart_upload(
          bucket: @bucket_name,
          key: key,
          upload_id: upload_id,
          multipart_upload: { parts: parts }
        )
      rescue => e
        @client.abort_multipart_upload(bucket: @bucket_name, key: key, upload_id: upload_id)
        raise e
      ensure
        io.close if io.respond_to?(:close) && !file_or_path.respond_to?(:read)
      end
    end
  end
end
