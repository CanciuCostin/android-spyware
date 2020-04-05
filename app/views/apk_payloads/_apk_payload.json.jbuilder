json.extract! apk_payload, :id, :destination_ip, :destination_port, :forwarding_ip, :forwarding_port, :created_at, :updated_at
json.url apk_payload_url(apk_payload, format: :json)
