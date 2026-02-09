FactoryBot.define do
  factory :social_media_message do
    smartphone { nil }
    app_name { "MyString" }
    sender { "MyString" }
    body { "MyText" }
    sent_at { "2026-02-09 17:13:58" }
  end
end
