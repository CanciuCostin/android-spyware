# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
AdminUser.create!(email: "admin@example.com", password: "password", password_confirmation: "password") if Rails.env.development?
ApkPayload.create!(id: 9999, destination_ip: "192.168.100.2", destination_port: "4444", forwarding_ip: "", forwarding_port: "", created_at: "2021-03-14", updated_at: "2021-03-14", name: "APK Payload") if Rails.env.development?
ApkInstallation.create!(id: 9999, target_ip: "USB", status: "", apk_payload_id: 9999) if Rails.env.development?
Smartphone.create!(id: 9999, operating_system: "Android", name: "Mock Smartphone", is_rooted: "false", is_app_hidden: "false", apk_installation_id: 9999, created_at: "2021-03-14", updated_at: "2021-03-14") if Rails.env.development?
