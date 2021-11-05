ActiveAdmin.register_page "Instructions" do
  menu priority: 5, label: "Instructions"

  content title: proc { "Instructions" } do
    text_node "Work in Progress"
  end
end
