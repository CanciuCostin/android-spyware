require 'rails_helper'

RSpec.describe 'Device Integrity', type: :system do
  let(:device) { create_installed_device(name: 'Integrity Phone', device_id: 'integrity-001') }

  before do
    driven_by(:rack_test)
    admin_login
  end

  it 'shows integrity status' do
    visit admin_smartphone_path(device)
    # Checks for presence of "Integrity Report" or "Root Status" section.
    # The user provided snippet checks for 'Integrity Report'. 
    # We will check for either as per the description requirements or stick to the snippet.
    # Let's try to match the snippet but be aware of the "or" requirement if it fails.
    # Given the snippet is explicit, I will follow it, but I will assume "Integrity Report" is the text.
    # If the UI shows "Root Status" instead, I might need to adjust.
    # However, for now, I will use the snippet.
    expect(page).to have_content('Integrity Report')
    expect(page).to have_link('Social Chats')
  end
end
