ActiveAdmin.register_page "Instructions" do
    menu priority: 1, label: proc { "Instructions" }, parent: "Actions"
  
    content title: proc { "Instructions" } do
  
      
  
  
    render partial: "admin/dashboard/carousel"
 
  
    end # content
  end
  