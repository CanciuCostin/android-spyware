ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }, parent: "Actions"

  content title: proc { I18n.t("active_admin.dashboard") } do


    #render partial: "switch"


    if params[:selected_smartphone_id].present?
        render template: "smartphones/dropdown_list_smartphones", locals: {smartphones: Smartphone.all, smartphone: Smartphone.find(params[:selected_smartphone_id])}
        puts 'true'
    else
        render template: "smartphones/dropdown_list_smartphones", locals: {smartphones: Smartphone.all, smartphone: Smartphone.first}
        puts 'false'
    end
    

    # div class: "blank_slate_container", id: "dashboard_default_message" do
    #   span class: "blank_slate" do
    #     span I18n.t("active_admin.dashboard_welcome.welcome")
    #     small I18n.t("active_admin.dashboard_welcome.call_to_action")
    #   end
    # end

    #render partial: "carousel"



    # Here is an example of a simple dashboard with columns and panels.
    #
    # columns do
    #   column do
    #     panel "Recent Posts" do
    #       ul do
    #         Post.recent(5).map do |post|
    #           li link_to(post.title, admin_post_path(post))
    #         end
    #       end
    #     end
    #   end

    #   column do
    #     panel "Info" do
    #       para "Welcome to ActiveAdmin."
    #     end
    #   end
    # end
  end # content
end
