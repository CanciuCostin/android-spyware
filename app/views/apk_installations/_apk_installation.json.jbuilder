json.extract! apk_installation, :id, :taget_ip, :status, :apk_payload_id, :created_at, :updated_at
json.url apk_installation_url(apk_installation, format: :json)
