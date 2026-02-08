require 'rails_helper'

RSpec.describe MsfRpcService do
  let(:service) { described_class.new }
  let(:rpc_client) { instance_double('Msf::RPC::Client') }
  let(:options) { { host: 'metasploit', port: 3333, uri: '/api/', ssl: true } }

  before do
    module ::Msf
      module RPC; end
    end

    stub_const('Msf::RPC::Client', class_double('Msf::RPC::Client'))
    allow(Msf::RPC::Client).to receive(:new).and_return(rpc_client)
    allow(CredentialsService).to receive(:msf_options).and_return(options)
    allow(CredentialsService).to receive(:msf_user).and_return('msf')
    allow(CredentialsService).to receive(:msf_password).and_return('secret')
  end

  describe '#connect' do
    it 'initializes and logs in' do
      expect(Msf::RPC::Client).to receive(:new).with(options).and_return(rpc_client)
      expect(rpc_client).to receive(:login).with('msf', 'secret')

      expect(service.connect).to eq(rpc_client)
    end
  end

  describe '#sessions' do
    before { service.instance_variable_set(:@rpc, rpc_client) }

    it 'returns list from msf rpc' do
      expect(rpc_client).to receive(:call).with('session.list').and_return('1' => {})

      expect(service.sessions).to eq('1' => {})
    end

    it 'recovers gracefully from errors' do
      allow(rpc_client).to receive(:call).and_raise(StandardError)

      expect(service.sessions).to eq({})
    end
  end

  describe '#android_session_id' do
    it 'finds first android meterpreter session' do
      allow(service).to receive(:sessions).and_return('5' => { 'type' => 'meterpreter', 'platform' => 'android' })

      expect(service.android_session_id).to eq('5')
    end
  end

  describe '#connected?' do
    it 'returns true when sessions exist' do
      allow(service).to receive(:sessions).and_return('1' => {})

      expect(service.connected?).to be true
    end

    it 'returns false when sessions call raises' do
      allow(service).to receive(:sessions).and_raise(StandardError)

      expect(service.connected?).to be false
    end
  end

  describe '#start_handler' do
    before do
      service.instance_variable_set(:@rpc, rpc_client)
    end

    it 'executes handler with default payload' do
      expect(rpc_client).to receive(:call).with('module.execute', 'exploit', 'multi/handler', hash_including('PAYLOAD' => described_class::ANDROID_PAYLOAD))

      service.start_handler
    end

    it 'raises SessionError when handler fails' do
      allow(rpc_client).to receive(:call).and_raise(StandardError, 'boom')

      expect { service.start_handler }.to raise_error(MsfRpcService::SessionError)
    end
  end

  describe '#detach_session' do
    before do
      service.instance_variable_set(:@rpc, rpc_client)
      allow(service).to receive(:sessions).and_return('10' => { 'platform' => 'android' })
      allow(service).to receive(:read_session_output).and_return(['line'])
      allow(Kernel).to receive(:sleep)
    end

    it 'detaches session and reads output' do
      expect(rpc_client).to receive(:call).with('session.meterpreter_session_detach', '10')

      expect(service.detach_session).to eq(['line'])
    end
  end

  describe '#read_session_output' do
    before do
      service.instance_variable_set(:@rpc, rpc_client)
    end

    it 'splits the returned output lines' do
      expect(rpc_client).to receive(:call).with('session.meterpreter_read', '12').and_return('key' => "one\ntwo")

      expect(service.read_session_output('12')).to eq(%w[one two])
    end

    it 'returns empty array on failure' do
      allow(rpc_client).to receive(:call).and_raise(StandardError)

      expect(service.read_session_output('12')).to eq([])
    end
  end
end
