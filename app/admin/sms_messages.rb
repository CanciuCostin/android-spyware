ActiveAdmin.register SmsMessage do
  menu parent: "📦 Data", priority: 4, label: "💬 SMS"
  permit_params :date, :source, :destination, :content, :smartphone_id, :filename

  includes :smartphone

  index do
    selectable_column
    id_column
    column :smartphone
    column :filename
    column :date
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
end
