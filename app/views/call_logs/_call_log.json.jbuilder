json.extract! call_log, :id, :date, :source, :destination, :duration, :filename, :smartphone_id, :created_at, :updated_at
json.url call_log_url(call_log, format: :json)
