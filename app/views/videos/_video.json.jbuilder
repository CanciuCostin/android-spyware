json.extract! video, :id, :date, :duration, :filename, :smartphone_id, :created_at, :updated_at
json.url video_url(video, format: :json)
