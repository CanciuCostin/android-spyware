json.extract! smartphone, :id, :operating_system, :name, :pictures, :screenshots, :videos, :recordings, :is_rooted, :call_logs, :contacts, :sms_messages, :geo_locations, :is_app_hidden, :created_at, :updated_at
json.url smartphone_url(smartphone, format: :json)
