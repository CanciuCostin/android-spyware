ActiveAdmin.register GeoLocation do
  menu parent: "📦 Data", priority: 8, label: "📍 Locations"

  permit_params :date, :lat, :long, :smartphone_id

  index do
    selectable_column
    id_column
    column :smartphone
    column :lat
    column :long
    column :date
    actions
  end

  # Integrated Map View
  action_item :view_map, only: :index do
    link_to 'View on Map', map_admin_geo_locations_path
  end

  collection_action :map, method: :get do
    @geo_locations = GeoLocation.includes(:smartphone).order(created_at: :desc).limit(1000)
    render 'admin/geo_locations/map'
  end
end

