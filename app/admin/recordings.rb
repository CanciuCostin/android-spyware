ActiveAdmin.register Recording do
  permit_params :date, :duration, :filename, :smartphone_id

  includes :smartphone

  index do
    selectable_column
    id_column
    column :smartphone
    column :filename
    column :duration
    column :date
    actions
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :smartphone, collection: Smartphone.all, include_blank: false
      f.input :filename
      f.input :duration
      f.input :date, as: :string, input_html: { type: :date }
    end
    f.actions
  end
end
