ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "Dashboard"

  controller do
    def index
      redirect_to '/dashboard'
    end
  end
end
