ActiveAdmin.register_page "Remote" do
    menu priority: 1, label: proc { "Remote" }, parent: "Actions"
  
    content title: proc { "Remote" } do
  
      
  
  
      #render partial: "switch"
      #render partial: "smartphones/dropdown_smartphones", smartphones: Smartphone.all, smartphone: Smartphone.first
  
      columns do
        if params[:selected_smartphone_id].present?
            column do
                render template: "smartphones/smartphone", locals: {smartphones: Smartphone.all, smartphone: Smartphone.find(params[:selected_smartphone_id])}
            end
        else
            column do
                render template: "smartphones/smartphone", locals: {smartphones: Smartphone.all, smartphone: Smartphone.first}
            end
        end
        column do
            render partial: "switcher"
        end
        column do
            render template: "smartphones/terminal"
        end

    end


    columns do
        column do
            render partial: "sliders"
        end
        column do
            render partial: "dropdown"
        end
        column do
            render partial: "input_counter"
        end
    end

    columns do
        column do
            render partial: "input_box"
        end
        column do
            render partial: "counter"
        end
        column do
        end
    end
      
  
    #    div class: "blank_slate_container", id: "dashboard_default_message" do
    #     span class: "blank_slate" do
    #       span I18n.t("active_admin.dashboard_welcome.welcome")
    #       small I18n.t("active_admin.dashboard_welcome.call_to_action")
    #     end
    #    end  
  
    end # content
  end
  