ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }, parent: "Actions"


  content title: proc { I18n.t("active_admin.dashboard") } do

    class Activity
        attr_reader :type
        attr_reader :date
        attr_reader :name
      
          def initialize(type,date,name)
          @type=type
          @date=date
          @name=name
          end
      end

    pictures=Picture.all.limit(10)
    activities=[]
    pictures.each do |picture|
        activities << Activity.new("Picture", picture.date, picture.filename)
    end







    


    columns do
        column do
          panel "Activities Timeline" do
                render partial: "timeline",    locals: {activities: activities}
          end
        end
  
        column do
                  panel "Stats" do
                    columns do
                        column do
                            render partial: "statistics_image", locals: {image_path: "users.png"}
                        end
                      
                        column do
                            render partial: "statistics_text", locals: {name: "Images", count: "132"}
                        end
                        column do
                            render partial: "statistics_image", locals: {image_path: "devices.png"}
                        end
                      
                        column do
                            render partial: "statistics_text", locals: {name: "Images", count: "132"}
                        end
                      end
                      columns do
                        column do
                            render partial: "statistics_image", locals: {image_path: "actions.png"}
                        end
                      
                        column do
                            render partial: "statistics_text", locals: {name: "Images", count: "132"}
                        end
                        column do
                            render partial: "statistics_image", locals: {image_path: "something.png"}
                        end
                      
                        column do
                            render partial: "statistics_text", locals: {name: "Images", count: "132"}
                        end
                      end
                      
                    end
                  end
                end


        columns do
            column do
                span "a"
            end
                    column class: "right_row" do
                    panel "Recent Pictures" do
                        table_for Picture.order("id desc").limit(10) do
                          column("id") { |picture| status_tag(picture.id) }
                          column("date") { |picture| picture.date }
                          column("filename")   { |picture| picture.filename }
                        end
                      end
                  end
                end


    #render partial: "switch"
    #render partial : "smartphones/dropdown_smartphones", smartphones: Smartphone.all, smartphone: Smartphone.first

    if params[:selected_smartphone_id].present?
        #render template: "smartphones/dropdown_list_smartphones", locals: {smartphones: Smartphone.all, smartphone: Smartphone.find(params[:selected_smartphone_id])}
        puts 'true'
    else
        #render template: "smartphones/dropdown_list_smartphones", locals: {smartphones: Smartphone.all, smartphone: Smartphone.first}
        puts 'false'
    end
    

    #  div class: "blank_slate_container", id: "dashboard_default_message" do
    #   span class: "blank_slate" do
    #     span I18n.t("active_admin.dashboard_welcome.welcome")
    #     small I18n.t("active_admin.dashboard_welcome.call_to_action")
    #   end
    #  end






    





  end # content
end
