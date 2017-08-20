
# Copyright (C) 2011-2013 Neil Stockbridge
# License: GPLv2

require "net/ssh"
require "json_rpc"

module HostAPI

  # Represents a remote host that has authorised JSON-RPC invocations via SSH.
  #
  # > rh = RemoteHost.new :hostname => "fine.example.com"
  # > ct = rh.context "com.example.System"
  # > puts ct.system_load
  # 0.01
  #
  class RemoteHost

    # Constructs a new object with which to interact with a particular remote
    # host.  Keys to `params` are:
    #
    # + hostname:     The fully qualified host name of the host
    # + remote_user:  The user on the remote host to connect as.  The default is
    #                 "root"
    # + key:          The filename ( within ~/.ssh/) of the key that permits this
    #                 host to execute the command on the remote host.  The
    #                 default is "id_rsa"
    # + transcript:   The stream on which to emit a transcript of the JSON-RPC
    #                 messages.  The default is not to emit. `$stdout` is a
    #                 typical value.  The default is not to emit
    #
    def initialize params
      @params = params
      # prevent Net::SSH from trying to contact the SSH agent
      ENV.delete "SSH_AGENT_PID"
      ENV.delete "SSH_AUTH_SOCK"
      # FIXME: More elegant to use KeyManager.use_agent=
    end


    # Provides an object with which to invoke remote methods in the specified
    # context.
    #
    def context namespace
      Context.new @params, namespace
    end


    class Context

      def initialize params, namespace
        @hostname = params[:hostname]
        @key = ( params[:key] or "id_rsa")
        @remote_user = ( params[:remote_user] or "root")
        @transcript = params[:transcript]

        @namespace = namespace
      end


      def method_missing method_name, *params

        method_name = @namespace+"/#{method_name}"
        @transcript.puts "  Invoking #{method_name} on #{@hostname} as #{@remote_user}" if @transcript
        transport = lambda do |request_as_json|

          response = ""
          params = {:auth_methods => ["publickey"],
                    :keys =>         [ENV["HOME"]+"/.ssh/"+@key],
                    :timeout =>       120,
          }
          Net::SSH.start @hostname, @remote_user, params do |session|

            session.open_channel do |channel|

              remote_command = "host-api"
              channel.exec  remote_command do |ch, success|

                if ! success
                  raise JsonRpc::Error.new -32603, "Could not invoke: #{remote_command}"
                end

                channel.on_data do |ch, output|
                  response += output
                end

                channel.on_extended_data do |ch, error|
                  # FIXME: Probably best to raise an exception
                  (@transcript or $stderr).puts "  Remote stderr: #{error}"
                end

                # Cause the automatic command to fire and produce its output in
                # the callback
                channel.send_data  request_as_json
                channel.process
                channel.eof!
              end
            end

            session.loop
          end

          response

        end
        remote = JsonRpc::Remote.new  transport
        remote.transcript = JsonRpc::StreamTranscript.new @transcript if @transcript
        remote.invoke_method  method_name, *params
      end

    end # of class Context

  end # of RemoteHost

end # of HostAPI

