require 'rails_helper'

RSpec.describe ResponseProcessor do
  let(:smartphone) { create(:smartphone, device_id: 'device-123') }
  let(:pending_command) { create(:pending_command, smartphone: smartphone, request_id: 'req-123', command: 'get_contacts') }
  let(:payload) do
    {
      'request_id' => pending_command.request_id,
      'contacts' => [{ 'name' => 'Alice' }]
    }
  end

  before do
    allow(HeartbeatMonitor).to receive(:process_heartbeat)
  end

  describe '.process' do
    it 'returns nil when payload is not a hash' do
      expect(PendingCommand).not_to receive(:find_by)
      expect(described_class.process('invalid')).to be_nil
    end

    it 'processes heartbeat payloads without pending commands' do
      heartbeat_payload = { 'type' => 'heartbeat', 'device_id' => smartphone.device_id }
      expect(HeartbeatMonitor).to receive(:process_heartbeat).with(smartphone.device_id, instance_of(Hash))
      described_class.process('payload' => heartbeat_payload)
    end

    it 'delegates to the correct response processor' do
      processor = instance_double('ContactsResponseProcessor', process: true)
      allow(ContactsResponseProcessor).to receive(:new).and_return(processor)

      described_class.process('payload' => payload)

      expect(ContactsResponseProcessor).to have_received(:new).with(pending_command, payload)
      expect(processor).to have_received(:process)
    end

    it 'marks pending command as failed when command type is unknown' do
      unlabeled = create(:pending_command, smartphone: smartphone, request_id: 'req-unknown', command: 'unsupported')
      allow(ContactsResponseProcessor).to receive(:new)
      allow(unlabeled).to receive(:mark_failed)

      described_class.process('payload' => { 'request_id' => unlabeled.request_id })

      expect(unlabeled).to have_received(:mark_failed).with("Unknown command type: unsupported")
    end

    it 'marks pending command as failed when processor raises' do
      processor = instance_double('ContactsResponseProcessor')
      allow(ContactsResponseProcessor).to receive(:new).and_return(processor)
      allow(processor).to receive(:process).and_raise(StandardError, 'boom')

      described_class.process('payload' => payload)

      expect(pending_command.reload.failed?).to be true
      expect(pending_command.response_data['error']).to eq('boom')
    end

    it 'skips processing when request_id is missing' do
      expect(PendingCommand).not_to receive(:find_by)
      described_class.process('payload' => { 'command' => 'get_contacts' })
    end
  end
end
