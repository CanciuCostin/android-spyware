class ContactsController < InheritedResources::Base

  private

    def contact_params
      params.require(:contact).permit(:first_name, :last_name, :phone_number, :smartphone_id)
    end

end
