require 'rails_helper'

RSpec.describe AiChatService do
  let(:device) { create(:smartphone) }
  let(:service) { described_class.new(device, message) }

  describe '#call' do
    context 'when querying social media chats' do
      let(:message) { "Show WhatsApp chats from Ivan" }

      before do
        # Create messages to test filtering
        create(:social_media_message, smartphone: device, app_name: 'WhatsApp', sender: 'Ivan', body: 'Hello there', sent_at: 1.hour.ago)
        create(:social_media_message, smartphone: device, app_name: 'WhatsApp', sender: 'Other', body: 'Hi', sent_at: 2.hours.ago)
        create(:social_media_message, smartphone: device, app_name: 'Telegram', sender: 'Ivan', body: 'Tg msg', sent_at: 3.hours.ago)
      end

      it 'filters by app name and sender' do
        result = service.call

        expect(result).to be_success
        data = result.value[:data]
        
        # Should find exactly one message (WhatsApp from Ivan)
        expect(data.size).to eq(1)
        expect(data.first[:app]).to eq('WhatsApp')
        expect(data.first[:sender]).to eq('Ivan')
        expect(data.first[:body]).to eq('Hello there')
      end

      it 'calls the correct model method with filters' do
        # We can spy on the model to verify the query construction
        relation = instance_double(ActiveRecord::Relation)
        # Allow any arguments for where/order/limit as Arel nodes are complex to match
        allow(relation).to receive(:where).and_return(relation)
        allow(relation).to receive(:order).and_return(relation)
        allow(relation).to receive(:limit).and_return([])

        # Mock the association chain: device.social_media_messages
        allow(device).to receive(:social_media_messages).and_return(relation)
        # Note: In real AR, association returns a relation-like proxy. 
        # Here we mock it to return our instance_double.

        service.call

        # Verify where was called to filter app and content
        expect(relation).to have_received(:where).at_least(:twice)
      end
    end

    context 'with LLM enabled' do
      let(:message) { "Show WhatsApp chats from Ivan" }
      let(:gemini_response) do
        {
          text: "Here are the chats",
          query: { model: 'SocialMediaMessage', conditions: { app_name: 'WhatsApp', sender: 'Ivan' } }
        }
      end

      before do
        allow(ENV).to receive(:[]).with('GEMINI_API_KEY').and_return('fake-key')
        allow(ENV).to receive(:fetch).and_call_original
      end

      it 'calls call_gemini and executes the returned query' do
        # Mock call_gemini
        expect(service).to receive(:call_gemini).and_return(gemini_response)
        
        # Mock execute_parsed_query to avoid actual DB call if we want unit isolation,
        # or we can let it run if we want integration test style.
        # Let's verify it tries to execute the query.
        expect(service).to receive(:execute_parsed_query).with(gemini_response[:query])
        
        service.call
      end
    end
  end
end
