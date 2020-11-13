ActiveAdmin.register_page "Instructions" do
  menu priority: 5, label: "Instructions"

  
    content title: proc { "Instructions" } do
  
      
  
  
    render partial: "admin/instructions/modal"


 
  
    end
  end
  