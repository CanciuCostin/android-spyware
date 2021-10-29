ActiveAdmin.register Picture do
  index do
    id_column
    column :filename
    column :date
    column :smartphone
    actions
  end

  index :as => :grid do |picture|
    div do
      resource_selection_cell picture
      a :href => admin_picture_path(picture) do
        image_tag("files/pictures/" + picture.filename, { :style => "width:100px;height:100px;" })
      end
    end
    a truncate(picture.filename), :href => admin_picture_path(picture)
  end
end
