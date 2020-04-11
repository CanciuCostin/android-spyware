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
            image_tag("files/pictures/" + picture.filename, {:style => "width:100px;height:100px;"})
          end
        end
        a truncate(picture.filename), :href => admin_picture_path(picture)
      end


  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  # permit_params :date, :duration, :filename, :smartphone_id
  #
  # or
  #
  # permit_params do
  #   permitted = [:date, :duration, :filename, :smartphone_id]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end
  
end
