json.extract! sms_message, :id, :date, :source, :destination, :content, :smartphone_id, :created_at, :updated_at
json.url sms_message_url(sms_message, format: :json)
