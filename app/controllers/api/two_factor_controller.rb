# frozen_string_literal: true

module Api
  class TwoFactorController < ApplicationController
    skip_before_action :authenticate_admin_user!, raise: false
    skip_before_action :verify_authenticity_token
    respond_to :json

    # POST /api/2fa/enable - Start 2FA setup
    def enable
      result = TwoFactorAuthService.enable(current_admin_user)

      render json: {
        status: 'setup_started',
        provisioning_uri: result[:provisioning_uri],
        qr_code_data: result[:qr_code_data],
        message: 'Scan the QR code with your authenticator app, then verify with a code.'
      }
    end

    # POST /api/2fa/verify - Verify TOTP code (activates 2FA or validates login)
    def verify
      code = params[:code]
      return render json: { error: 'Code is required' }, status: :bad_request if code.blank?

      two_factor = current_admin_user.admin_two_factor
      unless two_factor
        return render json: { error: 'Two-factor not configured. Call enable first.' }, status: :unprocessable_entity
      end

      if two_factor.enabled?
        # Already enabled: validate code for login
        result = TwoFactorAuthService.verify(current_admin_user, code)
      else
        # Not yet enabled: activate 2FA
        result = TwoFactorAuthService.verify_and_activate(current_admin_user, code)
      end

      if result[:success]
        response_data = { status: 'verified' }
        response_data[:backup_codes] = result[:backup_codes] if result[:backup_codes]
        response_data[:used_backup_code] = result[:used_backup_code] if result[:used_backup_code]
        response_data[:remaining_backup_codes] = result[:remaining_backup_codes] if result[:remaining_backup_codes]

        # Remember device if requested
        if params[:remember_device] && params[:device_fingerprint].present?
          TwoFactorAuthService.remember_device(current_admin_user, params[:device_fingerprint], request)
          response_data[:device_remembered] = true
        end

        render json: response_data
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end

    # POST /api/2fa/disable - Disable 2FA
    def disable
      code = params[:code]
      return render json: { error: 'Current TOTP code is required' }, status: :bad_request if code.blank?

      result = TwoFactorAuthService.disable(current_admin_user, code)

      if result[:success]
        render json: { status: 'disabled', message: 'Two-factor authentication has been disabled.' }
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end

    # GET /api/2fa/backup_codes - Generate new backup codes
    def backup_codes
      result = TwoFactorAuthService.regenerate_backup_codes(current_admin_user)

      if result[:success]
        render json: { backup_codes: result[:backup_codes], message: 'Store these codes securely. Previous codes are now invalid.' }
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end
  end
end
