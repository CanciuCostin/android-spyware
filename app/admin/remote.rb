ActiveAdmin.register_page "Remote" do
  menu priority: 6, label: "Remote"
  
    content title: proc { "Remote" } do
  
      
  
  
      #render partial: "switch"
      #render partial: "smartphones/dropdown_smartphones", smartphones: Smartphone.all, smartphone: Smartphone.first
  
      columns do
        column do
            columns do 

                if params[:selected_smartphone_id].present?
                    column do
                        render template: "smartphones/smartphone2", locals: {smartphones: Smartphone.all, smartphone: Smartphone.find(params[:selected_smartphone_id])}
                    end
                else
                    column do
                        render template: "smartphones/smartphone2", locals: {smartphones: Smartphone.all, smartphone: Smartphone.first}
                    end
                end

            end
            columns do
                column do
                    panel "Device Load "do
                        render partial: "gauges"
                    end
                end
            end
        end
    




        column do
            columns  do
                column class: "a" do
                    panel "Common Settings "do
                        columns do
                            column do
                            render partial: "toggle", locals: {label: "Auto Open Tab"}
                            end
                            column do
                            render partial: "toggle", locals: {label: "Auto Download"}
                            end
                        end
                        columns do
                            column do
                                render partial: "sliders", locals: {label: "Exec Timeout", min: "0s", max: "100s"}

                            end
                            column do
                                render partial: "sliders", locals: {label: "Cp Timeout", min: "0s", max: "100s"}
                            end
                        end
                    end
                end
            end

            columns do
                column do
                    panel "Specific Setings "do
                        tabs do
                            tab "Capture" do
                                columns do
                                    column do
                                        render partial: "input_box", locals: {input_name: "File Name"}
                                        render partial: "input_box", locals: {input_name: "File Path"}
                                    end
                                    column do
                                        render partial: "switcher"

                                    end
                                end
                                columns do
                                    column do
                                        render partial: "sliders", locals: {label: "Quality", min: "0%", max: "100%"}
                                    end
                                    column do
                                        render partial: "sliders", locals: {label: "Time", min: "0s", max: "100s"}

                                    end
                                end
                                #render partial: "sliders"
                            end
                            tab "SMS" do
                                render partial: "input_box", locals: {input_name: "Destination Number"}
                                render partial: "input_box", locals: {input_name: "Content"}
                            end
                            tab "Microphone" do
                                render partial: "dropdown"
                            end
                            tab "File System" do
                            end
                            tab "System Info" do
                            end
                            tab "Apps" do
                            end

                        end
                    end
                end
            end
        
    end


    column do
        columns do 
            column do
                render template: "smartphones/terminal"
            end
        end
        columns do
            column do
                panel "Platform Processes" do
                    render partial: "line_chart"
                end
            end
        end
    end

    end

   
   # render partial: "switcher"

    # columns do
    #     column do
    #         render partial: "sliders"
    #     end
    #     column do
    #          render partial: "dropdown"
    #     end
    #     column do
    #         render partial: "input_counter"
    #     end
    # end

    # columns do
    #     column do
    #         render partial: "input_box"
    #     end
    #     column do
    #         render partial: "counter"
    #     end
    #     column do
    #     end
    # end
      
  
    #    div class: "blank_slate_container", id: "dashboard_default_message" do
    #     span class: "blank_slate" do
    #       span I18n.t("active_admin.dashboard_welcome.welcome")
    #       small I18n.t("active_admin.dashboard_welcome.call_to_action")
    #     end
    #    end  
  
    end # content
  end
  