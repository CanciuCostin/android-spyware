ActiveAdmin.register Picture do
  menu parent: "📦 Data", priority: 5, label: "🖼️ Pictures"
  permit_params :date, :filename, :smartphone_id

  includes :smartphone

  index do
    selectable_column
    id_column
    column :filename
    column :date
    column :smartphone
    actions
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :smartphone, collection: Smartphone.all, include_blank: false
      f.input :filename
      f.input :date, as: :string, input_html: { type: :date }
    end
    f.actions
  end

  index :as => :grid do |picture|
    div do
      resource_selection_cell picture
      a :href => admin_picture_path(picture) do
        image_tag("files/dumps/pictures/" + picture.filename, { :style => "width:100px;height:100px;" })
      end
    end
    a truncate(picture.filename), :href => admin_picture_path(picture)
  end
end
