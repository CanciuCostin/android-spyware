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
                            render partial: "toggle", locals: {label: "Auto Open Tab", toggle_id: "open_toggle", tooltip_message: "If enabled, the output files will be opened in another tab when the task finishes."}
                            end
                            column do
                            render partial: "toggle", locals: {label: "Auto Download", toggle_id: "download_toggle", tooltip_message: "If enabled, the output files will be downloaded locally when the task finishes."}
                            end
                        end
                        columns do
                            column do
                                render partial: "sliders", locals: { label: "Exec Timeout", min: "0s", max: "100s", slider_id: "exec_timeout_slider", tooltip_message: "Set the timeout for executing the neccessery commands within the container."}
                                render partial: "triangle_info", locals: {color: "orange", tooltip_message: "Set common parameters for tasks"}

                            end
                            column do
                                render partial: "sliders", locals: {label: "Cp Timeout", min: "0s", max: "100s", slider_id: "cp_timeout_slider", tooltip_message: "Set the timeout for downloading the output files from the container."}
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
                                        render partial: "input_box", locals: {input_name: "File Name", input_id: "input_box_filename", tooltip_message: "Optionally set the name for the output file. The default is a timestamp for the current date."}
                                        render partial: "input_box", locals: {input_name: "File Path", input_id: "input_box_filepath", tooltip_message: "Optionally set the path for the output file."}
                                    end
                                    column do
                                        render partial: "switcher", locals: { items: ["Back Camera", "Front Camera"], items_ids: ["back_camera_input","front_camera_input"],
                                         switcher_id: "switcher_camera", tooltip_message: "Choose between front and back camera for webcam capture."}

                                    end
                                end
                                columns do
                                    column do
                                        render partial: "sliders", locals: {label: "Quality", min: "0%", max: "100%", slider_id: "slider_quality", tooltip_message: "Set the quality of the picture for webcam snaps."}
                                    end
                                    column do
                                        render partial: "sliders", locals: {label: "Time", min: "0s", max: "100s", slider_id: "slider_time", tooltip_message: "Set the record time in seconds for microphone and screen recordings."}
                                        render partial: "triangle_info", locals: {color: "red", tooltip_message: "Set specific parameters for the tasks"}


                                    end
                                end
                                #render partial: "sliders"
                            end
                            tab "SMS" do
                                render partial: "input_box", locals: {input_name: "Destination Number",input_id: "input_box_destination", tooltip_message: "Set the destination number for sending SMS."}
                                render partial: "input_box", locals: {input_name: "Content",input_id: "input_box_content", tooltip_message: "Set the content for sendind SMS."}
                            end
                            tab "Sound" do
                                render partial: "dropdown", locals: { items:["Silent","Sound", "Max"], dropdown_id: "dropdown_sound", tooltip_message: "Choose the sound mode you want to set on the device."}
                            end
                            tab "File System" do
                                columns do
                                    column do
                                        render partial: "input_box", locals: {input_name: "File to Pull", input_id: "input_box_pull_file", tooltip_message: "Set the path for the file you want to pull from the device."}
                                    end
                                    column do
                                        render partial: "input_box", locals: {input_name: "Destination Dir", input_id: "input_box_pull_file_destination", tooltip_message: "Set the destination directory for the file you want to pull."}


                                    end
                                end
                                columns do
                                    column do
                                        render partial: "input_box", locals: {input_name: "File to Push", input_id: "input_box_push_file", tooltip_message: "Set the path for the file you want to push on the device."}
                                    end
                                    column do
                                        render partial: "input_box", locals: {input_name: "Destination Dir", input_id: "input_box_push_file_destination", tooltip_message: "Set the destination directory for the file you want to pull."}


                                    end
                                end
                            end
                            tab "System" do
                                columns do
                                    #column do
                                    #    render partial: "dropdown", locals: { items:["Enable Wake","Disable Wake", "Unlock Screen"], dropdown_id: "dropdown_wakelock", tooltip_message: "Choose the wakelock mode."}

                                    #end
                                    column do
                                        render partial: "input_box", locals: {input_name: "Shell Command", input_id: "input_box_shell_command", tooltip_message: "Set the shell command you want to run on the device."}


                                    end
                                end
                            end
                            tab "Applications" do
                                columns do
                                    column do
                                        render partial: "input_box", locals: {input_name: "Uninstall App Name", input_id: "input_box_application", tooltip_message: "Set the application package you want to uninstall: e.g. com.whatsapp"}
                                        render partial: "input_box", locals: {input_name: "Install APK Path", input_id: "input_box_apkpath", tooltip_message: "Set the path for the APK to install on the device."}
                                    end
                                    column do
                                        render partial: "toggle", locals: {label: "System Apps", toggle_id: "system_apps_toggle", tooltip_message: "Display only installed system applications."}
                                        render partial: "toggle", locals: {label: "Users Apps", toggle_id: "user_apps_toggle", tooltip_message: "Display only installed user applications."}


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
                    render partial: "triangle_info", locals: {color: "green", tooltip_message: "The visualization shows real time counts for running vs finished tasks triggered within the platform"}

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
  