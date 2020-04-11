ActiveAdmin.register_page "Remote" do
    menu priority: 1, label: proc { "Remote" }, parent: "Actions"
  
    content title: proc { "Remote" } do
  
      
  
  
      #render partial: "switch"
      render partial : "smartphones/dropdown_smartphones", smartphones: Smartphone.all, smartphone: Smartphone.first
  
      if params[:selected_smartphone_id].present?
          #render template: "smartphones/dropdown_list_smartphones", locals: {smartphones: Smartphone.all, smartphone: Smartphone.find(params[:selected_smartphone_id])}
          puts 'true'
      else
          #render template: "smartphones/dropdown_list_smartphones", locals: {smartphones: Smartphone.all, smartphone: Smartphone.first}
          puts 'false'
      end
      
  
    #    div class: "blank_slate_container", id: "dashboard_default_message" do
    #     span class: "blank_slate" do
    #       span I18n.t("active_admin.dashboard_welcome.welcome")
    #       small I18n.t("active_admin.dashboard_welcome.call_to_action")
    #     end
    #    end  
  
    end # content
  end
  