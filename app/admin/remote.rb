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
                        render partial: "triangle_info", locals: {color: "orange"}

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
                            render partial: "toggle", locals: {label: "Auto Open Tab", toggle_id: "open_toggle"}
                            end
                            column do
                            render partial: "toggle", locals: {label: "Auto Download", toggle_id: "download_toggle"}
                            end
                        end
                        columns do
                            column do
                                render partial: "sliders", locals: { label: "Exec Timeout", min: "0s", max: "100s", slider_id: "exec_timeout_slider"}
                                render partial: "triangle_info", locals: {color: "orange"}

                            end
                            column do
                                render partial: "sliders", locals: {label: "Cp Timeout", min: "0s", max: "100s", slider_id: "cp_timeout_slider"}
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
                                        render partial: "input_box", locals: {input_name: "File Name", input_id: "input_box_filename"}
                                        render partial: "input_box", locals: {input_name: "File Path", input_id: "input_box_filepath"}
                                    end
                                    column do
                                        render partial: "switcher", locals: { items: ["Back Camera", "Front Camera"], switcher_id: "switcher_camera"}

                                    end
                                end
                                columns do
                                    column do
                                        render partial: "sliders", locals: {label: "Quality", min: "0%", max: "100%", slider_id: "slider_quality"}
                                    end
                                    column do
                                        render partial: "sliders", locals: {label: "Time", min: "0s", max: "100s", slider_id: "slider_time"}
                                        render partial: "triangle_info", locals: {color: "orange"}


                                    end
                                end
                                #render partial: "sliders"
                            end
                            tab "SMS" do
                                render partial: "input_box", locals: {input_name: "Destination Number",input_id: "input_box_destination"}
                                render partial: "input_box", locals: {input_name: "Content",input_id: "input_box_content"}
                            end
                            tab "Sound" do
                                render partial: "dropdown", locals: { items:["Silent","Sound", "Max"], dropdown_id: "dropdown_sound"}
                            end
                            tab "File System" do
                                columns do
                                    column do
                                        render partial: "input_box", locals: {input_name: "File to Pull", input_id: "input_box_pull_file"}
                                    end
                                    column do
                                        render partial: "input_box", locals: {input_name: "Destination Dir", input_id: "input_box_pull_file_destination"}


                                    end
                                end
                                columns do
                                    column do
                                        render partial: "input_box", locals: {input_name: "File to Push", input_id: "input_box_push_file"}
                                    end
                                    column do
                                        render partial: "input_box", locals: {input_name: "Destination Dir", input_id: "input_box_push_file_destination"}


                                    end
                                end
                            end
                            tab "System" do
                                columns do
                                    column do
                                        render partial: "dropdown", locals: { items:["Enable Wake","Disable Wake", "Unlock Screen"], dropdown_id: "dropdown_wakelock"}

                                    end
                                    column do
                                        render partial: "input_box", locals: {input_name: "Shell Command", input_id: "input_box_shell_command"}


                                    end
                                end
                            end
                            tab "Applications" do
                                columns do
                                    column do
                                        render partial: "input_box", locals: {input_name: "Uninstall App Name", input_id: "input_box_application"}
                                        render partial: "input_box", locals: {input_name: "Install APK Path", input_id: "input_box_apkpath"}
                                    end
                                    column do
                                        render partial: "toggle", locals: {label: "System Apps", toggle_id: "system_apps_toggle"}
                                        render partial: "toggle", locals: {label: "User   Apps", toggle_id: "user_apps_toggle"}


                                    end
                                end
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
                    render partial: "triangle_info", locals: {color: "orange"}

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
  