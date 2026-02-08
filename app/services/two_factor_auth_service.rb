# frozen_string_literal: true

# TOTP-based two-factor authentication service.
# Uses HMAC-based OTP (RFC 6238) with 30-second time steps.
class TwoFactorAuthService
  OTP_DIGITS = 6
  OTP_INTERVAL = 30
  OTP_ALGORITHM = 'sha1'
  BACKUP_CODE_COUNT = 10
  BACKUP_CODE_LENGTH = 8
  REMEMBER_DEVICE_DAYS = 30
  DRIFT_SECONDS = 30

  class << self
    # Generate a new OTP secret (Base32-encoded, 20 bytes)
    def generate_secret
      SecureRandom.random_bytes(20).unpack('C*').map { |b|
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'[b % 32]
      }.join
    end

    # Enable 2FA for an admin user, returning the secret and provisioning URI
    def enable(admin_user)
      secret = generate_secret
      two_factor = admin_user.admin_two_factor || admin_user.build_admin_two_factor
      two_factor.update!(
        otp_secret: secret,
        enabled: false,
        backup_codes: [],
        failed_attempts: 0,
        locked_until: nil
      )

      {
        secret: secret,
        provisioning_uri: provisioning_uri(admin_user.email, secret),
        qr_code_data: qr_code_svg(admin_user.email, secret)
      }
    end

    # Verify a TOTP code and finalize 2FA activation
    def verify_and_activate(admin_user, code)
      two_factor = admin_user.admin_two_factor
      return { success: false, error: 'Two-factor not configured' } unless two_factor
      return { success: false, error: 'Account temporarily locked' } if two_factor.locked?

      if valid_totp?(two_factor.otp_secret, code)
        backup_codes = generate_backup_codes
        two_factor.update!(enabled: true, backup_codes: backup_codes, last_used_at: Time.current)
        two_factor.reset_failed_attempts!
        { success: true, backup_codes: backup_codes }
      else
        two_factor.record_failed_attempt!
        { success: false, error: 'Invalid verification code' }
      end
    end

    # Verify a TOTP code for login (supports backup codes)
    def verify(admin_user, code)
      two_factor = admin_user.admin_two_factor
      return { success: true } unless two_factor&.enabled?
      return { success: false, error: 'Account temporarily locked' } if two_factor.locked?

      if valid_totp?(two_factor.otp_secret, code)
        two_factor.update!(last_used_at: Time.current)
        two_factor.reset_failed_attempts!
        { success: true }
      elsif two_factor.consume_backup_code!(code)
        { success: true, used_backup_code: true, remaining_backup_codes: two_factor.backup_codes.size }
      else
        two_factor.record_failed_attempt!
        { success: false, error: 'Invalid verification code' }
      end
    end

    # Disable 2FA for an admin user
    def disable(admin_user, code)
      two_factor = admin_user.admin_two_factor
      return { success: false, error: 'Two-factor not enabled' } unless two_factor&.enabled?

      unless valid_totp?(two_factor.otp_secret, code)
        return { success: false, error: 'Invalid verification code' }
      end

      two_factor.update!(enabled: false, otp_secret: generate_secret, backup_codes: [])
      { success: true }
    end

    # Generate fresh backup codes (invalidates old ones)
    def regenerate_backup_codes(admin_user)
      two_factor = admin_user.admin_two_factor
      return { success: false, error: 'Two-factor not enabled' } unless two_factor&.enabled?

      codes = generate_backup_codes
      two_factor.update!(backup_codes: codes)
      { success: true, backup_codes: codes }
    end

    # Check if a device is remembered (skip 2FA)
    def device_remembered?(admin_user, fingerprint)
      admin_user.remembered_devices.valid.exists?(device_fingerprint: fingerprint)
    end

    # Remember a device for REMEMBER_DEVICE_DAYS
    def remember_device(admin_user, fingerprint, request)
      admin_user.remembered_devices.find_or_initialize_by(device_fingerprint: fingerprint).tap do |rd|
        rd.update!(
          user_agent: request.user_agent&.truncate(255),
          ip_address: request.remote_ip,
          expires_at: REMEMBER_DEVICE_DAYS.days.from_now
        )
      end
    end

    # Forget a device
    def forget_device(admin_user, fingerprint)
      admin_user.remembered_devices.where(device_fingerprint: fingerprint).destroy_all
    end

    private

    def valid_totp?(secret, code)
      return false if code.blank? || secret.blank?

      code = code.to_s.gsub(/\s/, '')
      now = Time.current.to_i

      # Check current interval and ± 1 step for clock drift
      (-1..1).any? do |drift|
        expected = compute_totp(secret, now + (drift * OTP_INTERVAL))
        ActiveSupport::SecurityUtils.secure_compare(code, expected)
      end
    end

    def compute_totp(secret, time)
      counter = time / OTP_INTERVAL
      counter_bytes = [counter].pack('Q>') # 8-byte big-endian

      key = base32_decode(secret)
      hmac = OpenSSL::HMAC.digest(OTP_ALGORITHM, key, counter_bytes)

      offset = hmac[-1].ord & 0x0F
      truncated = (hmac[offset].ord & 0x7F) << 24 |
                  (hmac[offset + 1].ord & 0xFF) << 16 |
                  (hmac[offset + 2].ord & 0xFF) << 8 |
                  (hmac[offset + 3].ord & 0xFF)

      (truncated % (10**OTP_DIGITS)).to_s.rjust(OTP_DIGITS, '0')
    end

    def base32_decode(str)
      alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
      bits = str.upcase.chars.map { |c| alphabet.index(c).to_i.to_s(2).rjust(5, '0') }.join
      bits.scan(/.{8}/).map { |byte| byte.to_i(2).chr }.join
    end

    def provisioning_uri(email, secret)
      issuer = 'EagleSpy'
      label = "#{issuer}:#{email}"
      params = URI.encode_www_form(secret: secret, issuer: issuer, algorithm: OTP_ALGORITHM.upcase, digits: OTP_DIGITS, period: OTP_INTERVAL)
      "otpauth://totp/#{URI.encode_www_form_component(label)}?#{params}"
    end

    def qr_code_svg(email, secret)
      uri = provisioning_uri(email, secret)
      # Return data for client-side QR generation (avoids server-side QR gem dependency)
      { provisioning_uri: uri, manual_entry_key: secret }
    end

    def generate_backup_codes
      BACKUP_CODE_COUNT.times.map { SecureRandom.alphanumeric(BACKUP_CODE_LENGTH).downcase }
    end
  end
end
