require 'rails_helper'

RSpec.describe ContactsResponseProcessor do
  let(:smartphone) { create(:smartphone, device_id: 'device-123') }
  let(:pending_command) { create(:pending_command, smartphone: smartphone, command: 'get_contacts') }
  
  after do
    # Cleanup test files
    FileUtils.rm_rf(Rails.root.join('files', 'dumps', 'contacts_dumps'))
  end
  
  describe '#process' do
    context 'with valid contacts data' do
      let(:response) do
        {
          'contacts' => [
            {
              'name' => 'Alice Smith',
              'phone_number' => '+1234567890',
              'email' => 'alice@example.com'
            },
            {
              'name' => 'Bob Jones',
              'phone_number' => '+0987654321',
              'email' => 'bob@example.com'
            }
          ]
        }
      end
      
      it 'creates a Contact record' do
        expect {
          described_class.new(pending_command, response).process
        }.to change(Contact, :count).by(1)
        
        contact = Contact.last
        expect(contact.smartphone).to eq(smartphone)
        expect(contact.filename).to match(/contacts_dump_\d{4}-\d{2}-\d{2}_\d{2}--\d{2}--\d{2}\.txt/)
      end
      
      it 'creates a file with contact data' do
        described_class.new(pending_command, response).process
        
        contact_files = Dir.glob(Rails.root.join('files', 'dumps', 'contacts_dumps', 'contacts_dump_*.txt'))
        expect(contact_files).not_to be_empty
        
        file_content = File.read(contact_files.first)
        expect(file_content).to include('Name: Alice Smith')
        expect(file_content).to include('Phone: +1234567890')
        expect(file_content).to include('Email: alice@example.com')
        expect(file_content).to include('Name: Bob Jones')
      end
      
      it 'marks pending command as completed' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('completed')
        expect(pending_command.response_data).to eq(response)
      end
      
      it 'formats contact data correctly' do
        described_class.new(pending_command, response).process
        
        contact_files = Dir.glob(Rails.root.join('files', 'dumps', 'contacts_dumps', 'contacts_dump_*.txt'))
        file_content = File.read(contact_files.first)
        
        # Check formatting with blank lines between contacts
        expect(file_content).to match(/Name: Alice Smith\nPhone: \+1234567890\nEmail: alice@example\.com\n\n/)
      end
    end
    
    context 'with empty contacts array' do
      let(:response) { { 'contacts' => [] } }
      
      it 'creates a Contact record with empty file' do
        expect {
          described_class.new(pending_command, response).process
        }.to change(Contact, :count).by(1)
      end
      
      it 'creates an empty file' do
        described_class.new(pending_command, response).process
        
        contact_files = Dir.glob(Rails.root.join('files', 'dumps', 'contacts_dumps', 'contacts_dump_*.txt'))
        expect(contact_files).not_to be_empty
        expect(File.read(contact_files.first)).to eq('')
      end
    end
    
    context 'with missing contacts key' do
      let(:response) { {} }
      
      it 'creates a Contact record with empty file' do
        expect {
          described_class.new(pending_command, response).process
        }.to change(Contact, :count).by(1)
      end
      
      it 'creates an empty file' do
        described_class.new(pending_command, response).process
        
        contact_files = Dir.glob(Rails.root.join('files', 'dumps', 'contacts_dumps', 'contacts_dump_*.txt'))
        expect(File.read(contact_files.first)).to eq('')
      end
    end
    
    context 'with partial contact data' do
      let(:response) do
        {
          'contacts' => [
            {
              'name' => 'Charlie',
              'phone_number' => nil,
              'email' => nil
            },
            {
              'name' => nil,
              'phone_number' => '+1111111111',
              'email' => 'test@example.com'
            }
          ]
        }
      end
      
      it 'handles nil values gracefully' do
        described_class.new(pending_command, response).process
        
        contact_files = Dir.glob(Rails.root.join('files', 'dumps', 'contacts_dumps', 'contacts_dump_*.txt'))
        file_content = File.read(contact_files.first)
        
        expect(file_content).to include('Name: Charlie')
        expect(file_content).to include('Phone: ')
        expect(file_content).to include('Email: ')
      end
    end
    
    context 'with special characters in contact data' do
      let(:response) do
        {
          'contacts' => [
            {
              'name' => "O'Brien & Co.",
              'phone_number' => '+1-234-567-8900',
              'email' => 'test+tag@example.com'
            }
          ]
        }
      end
      
      it 'preserves special characters' do
        described_class.new(pending_command, response).process
        
        contact_files = Dir.glob(Rails.root.join('files', 'dumps', 'contacts_dumps', 'contacts_dump_*.txt'))
        file_content = File.read(contact_files.first)
        
        expect(file_content).to include("O'Brien & Co.")
        expect(file_content).to include('+1-234-567-8900')
        expect(file_content).to include('test+tag@example.com')
      end
    end
    
    context 'when file directory cannot be created' do
      before do
        allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES, 'Permission denied')
      end
      
      it 'raises an error' do
        expect {
          described_class.new(pending_command, response).process
        }.to raise_error(Errno::EACCES)
      end
    end
    
    context 'when Contact creation fails' do
      let(:response) { { 'contacts' => [] } }
      
      before do
        allow(Contact).to receive(:find_or_create_by!).and_raise(ActiveRecord::RecordInvalid)
      end
      
      it 'raises an error' do
        expect {
          described_class.new(pending_command, response).process
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
    
    context 'with large number of contacts' do
      let(:response) do
        {
          'contacts' => Array.new(1000) do |i|
            {
              'name' => "Contact #{i}",
              'phone_number' => "+#{i}",
              'email' => "contact#{i}@example.com"
            }
          end
        }
      end
      
      it 'processes all contacts successfully' do
        expect {
          described_class.new(pending_command, response).process
        }.to change(Contact, :count).by(1)
        
        contact_files = Dir.glob(Rails.root.join('files', 'dumps', 'contacts_dumps', 'contacts_dump_*.txt'))
        file_content = File.read(contact_files.first)
        
        expect(file_content).to include('Contact 0')
        expect(file_content).to include('Contact 999')
      end
    end
  end
end
