# frozen_string_literal: true

class DeepfakeDetectionService < ApplicationService
  KNOWN_SPOOF_APPS = %w[
    com.lexa.fakegps
    com.incorporateapps.fakegps.fre
    com.fakegps.mock
    com.blogspot.newapphorizons.fakegps
    ru.gavrikov.mocklocations
    com.evezzon.fakegps
    com.gsmartstudio.fakegps
    com.lkr.fakelocation
    com.martial.fakegps
  ].freeze

  SUSPICIOUS_EXIF_SOFTWARE = %w[
    photoshop gimp faceapp deepfake fakeapp reface
  ].freeze

  # Frequency bands typical for synthetic speech (Hz)
  SYNTHETIC_VOICE_BANDS = {
    low_cutoff: 80,
    high_cutoff: 8000,
    formant_gap_min: 200,
    formant_gap_max: 4000
  }.freeze

  def initialize(smartphone, analysis_type: :full, data: {})
    @smartphone = smartphone
    @analysis_type = analysis_type
    @data = data
  end

  def call
    return Result.failure('Smartphone is required') unless @smartphone

    results = case @analysis_type
              when :gps
                analyze_gps
              when :media
                analyze_media
              when :voice
                analyze_voice
              when :tamper
                analyze_tamper
              when :full
                {
                  gps: analyze_gps,
                  media: analyze_media,
                  voice: analyze_voice,
                  tamper: analyze_tamper
                }
              else
                return Result.failure("Unknown analysis type: #{@analysis_type}")
              end

    Result.success(results)
  rescue StandardError => e
    Rails.logger.error("[DeepfakeDetectionService] Error: #{e.message}")
    Result.failure(e.message)
  end

  private

  def analyze_gps
    detector = GpsSpoofingDetector.new(@smartphone, @data.slice(:latitude, :longitude, :accuracy, :provider, :installed_apps))
    result = detector.call
    record_event(:gps_analysis, result) if result.success?
    result.success? ? result.value : { error: result.error }
  end

  def analyze_media
    media_data = @data.slice(:file_path, :exif_data, :file_size, :mime_type)
    findings = []

    if media_data[:exif_data].present?
      findings.concat(check_exif_integrity(media_data[:exif_data]))
    end

    findings.concat(check_compression_artifacts(media_data))
    findings.concat(check_metadata_consistency(media_data))

    severity = findings.any? { |f| f[:severity] == :high } ? :high : :low
    record_event(:media_analysis, severity: severity, findings: findings) if findings.any?

    { suspicious: findings.any?, findings: findings, severity: severity }
  end

  def analyze_voice
    audio_data = @data.slice(:sample_rate, :duration, :frequency_bands, :silence_ratio)
    indicators = []

    if audio_data[:sample_rate].present?
      sr = audio_data[:sample_rate].to_i
      if sr < SYNTHETIC_VOICE_BANDS[:low_cutoff] * 2
        indicators << { indicator: 'low_sample_rate', detail: "Sample rate #{sr}Hz below natural speech minimum", severity: :medium }
      end
    end

    if audio_data[:frequency_bands].present?
      indicators.concat(analyze_frequency_distribution(audio_data[:frequency_bands]))
    end

    if audio_data[:silence_ratio].present?
      ratio = audio_data[:silence_ratio].to_f
      if ratio > 0.7
        indicators << { indicator: 'excessive_silence', detail: "Silence ratio #{(ratio * 100).round(1)}% abnormally high", severity: :low }
      end
    end

    severity = compute_severity(indicators)
    record_event(:voice_analysis, severity: severity, indicators: indicators) if indicators.any?

    { suspicious: indicators.any?, indicators: indicators, severity: severity }
  end

  def analyze_tamper
    tamper_data = @data.slice(:app_signature, :is_debuggable, :is_rooted, :installer_package, :build_type)
    flags = []

    if tamper_data[:is_debuggable]
      flags << { flag: 'debug_mode', detail: 'Application is running in debug mode', severity: :high }
    end

    if tamper_data[:app_signature].present?
      expected = ENV['EXPECTED_APP_SIGNATURE']
      if expected.present? && tamper_data[:app_signature] != expected
        flags << { flag: 'signature_mismatch', detail: 'App signature does not match expected value', severity: :critical }
      end
    end

    if tamper_data[:installer_package].present?
      unless %w[com.android.vending com.google.android.feedback].include?(tamper_data[:installer_package])
        flags << { flag: 'sideloaded', detail: "Installed via #{tamper_data[:installer_package]}", severity: :medium }
      end
    end

    if tamper_data[:build_type] == 'debug'
      flags << { flag: 'debug_build', detail: 'Running a debug build variant', severity: :high }
    end

    severity = compute_severity(flags)
    record_event(:tamper_detection, severity: severity, flags: flags) if flags.any?

    { tampered: flags.any?, flags: flags, severity: severity }
  end

  def check_exif_integrity(exif_data)
    findings = []

    if exif_data[:software].present?
      sw = exif_data[:software].to_s.downcase
      if SUSPICIOUS_EXIF_SOFTWARE.any? { |s| sw.include?(s) }
        findings << { finding: 'suspicious_software', detail: "EXIF software: #{exif_data[:software]}", severity: :high }
      end
    end

    if exif_data[:gps_latitude].present? && exif_data[:datetime].blank?
      findings << { finding: 'missing_datetime', detail: 'GPS data present but no capture datetime', severity: :medium }
    end

    if exif_data[:thumbnail_offset].present? && exif_data[:thumbnail_offset].to_i == 0
      findings << { finding: 'stripped_thumbnail', detail: 'Thumbnail data appears stripped', severity: :low }
    end

    findings
  end

  def check_compression_artifacts(media_data)
    findings = []

    if media_data[:mime_type] == 'image/jpeg' && media_data[:file_size].present?
      size_kb = media_data[:file_size].to_i / 1024.0
      if size_kb < 10
        findings << { finding: 'over_compressed', detail: "JPEG unusually small (#{size_kb.round(1)}KB)", severity: :medium }
      end
    end

    findings
  end

  def check_metadata_consistency(media_data)
    findings = []

    if media_data[:exif_data].present?
      exif = media_data[:exif_data]
      if exif[:make].blank? && exif[:model].blank? && exif[:gps_latitude].present?
        findings << { finding: 'synthetic_metadata', detail: 'GPS data present without camera identification', severity: :medium }
      end
    end

    findings
  end

  def analyze_frequency_distribution(bands)
    indicators = []

    if bands.is_a?(Hash)
      total_energy = bands.values.map(&:to_f).sum
      return indicators if total_energy.zero?

      high_freq_energy = bands.select { |k, _| k.to_i > SYNTHETIC_VOICE_BANDS[:high_cutoff] }.values.map(&:to_f).sum
      high_ratio = high_freq_energy / total_energy

      if high_ratio < 0.05
        indicators << { indicator: 'missing_high_frequencies', detail: 'Unnaturally absent high-frequency content', severity: :medium }
      end

      low_freq_energy = bands.select { |k, _| k.to_i < SYNTHETIC_VOICE_BANDS[:low_cutoff] }.values.map(&:to_f).sum
      if low_freq_energy / total_energy > 0.4
        indicators << { indicator: 'excessive_low_frequencies', detail: 'Unusual low-frequency dominance', severity: :low }
      end
    end

    indicators
  end

  def compute_severity(items)
    return :none if items.empty?
    return :critical if items.any? { |i| i[:severity] == :critical }
    return :high if items.any? { |i| i[:severity] == :high }
    return :medium if items.any? { |i| i[:severity] == :medium }

    :low
  end

  def record_event(event_type, details = {})
    SecurityEvent.create!(
      device_id: @smartphone.device_id,
      event_type: event_type.to_s,
      severity: (details[:severity] || :info).to_s,
      details: details.to_json,
      detected_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.warn("[DeepfakeDetectionService] Failed to record event: #{e.message}")
  end
end
