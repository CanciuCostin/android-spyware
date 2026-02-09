# frozen_string_literal: true

# Per-device API key management with generation, rotation, revocation, and scoping.
class ApiKeyService
  KEY_PREFIX_LENGTH = 8
  KEY_LENGTH = 48

  class << self
    # Generate a new API key for a device or admin
    def generate(name:, scope: 'read_only', device_id: nil, admin_user: nil, expires_in: nil)
      raw_key = SecureRandom.urlsafe_base64(KEY_LENGTH)
      prefix = raw_key[0...KEY_PREFIX_LENGTH]
      digest = Digest::SHA256.hexdigest(raw_key)

      api_key = ApiKey.create!(
        name: name,
        key_digest: digest,
        key_prefix: prefix,
        scope: scope,
        device_id: device_id,
        admin_user: admin_user,
        expires_at: expires_in ? expires_in.from_now : nil
      )

      # Return the raw key only once (never stored in plaintext)
      {
        id: api_key.id,
        key: raw_key,
        prefix: prefix,
        name: name,
        scope: scope,
        device_id: device_id,
        expires_at: api_key.expires_at
      }
    end

    # Authenticate a request using an API key
    def authenticate(raw_key)
      return nil if raw_key.blank?

      digest = Digest::SHA256.hexdigest(raw_key)
      api_key = ApiKey.find_by(key_digest: digest)

      return nil unless api_key&.active?

      api_key.track_usage!
      api_key
    end

    # Rotate a key: revoke old, generate new with same attributes
    def rotate(api_key_id)
      old_key = ApiKey.find(api_key_id)
      return { success: false, error: 'Key already revoked' } if old_key.revoked?

      old_key.revoke!

      new_key = generate(
        name: old_key.name,
        scope: old_key.scope,
        device_id: old_key.device_id,
        admin_user: old_key.admin_user
      )

      { success: true, old_key_id: old_key.id, new_key: new_key }
    end

    # Revoke a specific key
    def revoke(api_key_id)
      api_key = ApiKey.find(api_key_id)
      api_key.revoke!
      { success: true, revoked_at: api_key.revoked_at }
    end

    # Revoke all keys for a device
    def revoke_all_for_device(device_id)
      keys = ApiKey.active.for_device(device_id)
      count = keys.count
      keys.update_all(revoked: true, revoked_at: Time.current)
      { success: true, revoked_count: count }
    end

    # List active keys (redacted: no raw key shown)
    def list(device_id: nil, admin_user: nil)
      keys = ApiKey.active
      keys = keys.for_device(device_id) if device_id
      keys = keys.where(admin_user: admin_user) if admin_user

      keys.order(created_at: :desc).map do |k|
        {
          id: k.id,
          prefix: k.key_prefix,
          name: k.name,
          scope: k.scope,
          device_id: k.device_id,
          usage_count: k.usage_count,
          last_used_at: k.last_used_at,
          expires_at: k.expires_at,
          created_at: k.created_at
        }
      end
    end

    # Usage statistics for a key
    def usage_stats(api_key_id)
      api_key = ApiKey.find(api_key_id)
      {
        id: api_key.id,
        name: api_key.name,
        usage_count: api_key.usage_count,
        last_used_at: api_key.last_used_at,
        created_at: api_key.created_at,
        active: api_key.active?
      }
    end
  end
end
