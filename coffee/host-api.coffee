
process = require 'process'
Path = require 'path'
fs = require 'fs'
SSH = require 'ssh2'
JsonRpc = require './json-rpc'



# Represents a remote host that has authorized JSON-RPC invocations via SSH.
#
# > rh = new RemoteHost hostname: 'fine.example.com'
# > ct = rh.context 'com.example.System', ['system_load']
# > p ct.system_load()
# 0.01
#
class RemoteHost

  # Constructs a new object with which to interact with a particular remote
  # host.  Parameters
  #
  # + hostname:     The fully qualified host name of the host
  # + remote_user:  The user on the remote host to connect as.  The default is
  #                 'root'
  # + key:          The filename ( within ~/.ssh/) of the key that permits this
  #                 host to execute the command on the remote host.  The
  #                 default is 'id_rsa'
  # + transcript:   The stream on which to emit a transcript of the JSON-RPC
  #                 messages.  The default is to be quiet.
  #
  constructor: (@params) ->
    @params.key ?= 'id_rsa'
    @params.remote_user ?= 'root'


  # Provides an object with which to invoke remote methods in the specified
  # context.
  #
  # @param  namespace   :String such as 'com.example.System'
  # @param  methods     :Array such as ['ping', 'add']
  #
  context: (namespace, methods) ->
    new Context @params, namespace, methods


  Context: class Context

    constructor: (params, @namespace, methods) ->
      @[property] = value for property, value of params

      path_to_key = Path.join  process.env.HOME, '.ssh', @key
      hostname = @hostname
      remote_user = @remote_user

      transport =

        message_id: 0

        next_message_id: ->
          @message_id += 1

        request: (request_as_json, callback) ->
          # Move this to RemoteHost and then re-use the connection for multiple
          # requests.
          session = new SSH.Client()
          session.on 'ready', ->
            # The remote command is ignored, but just in case..
            remote_command = 'host-api'
            session.exec  remote_command, (e, stream) ->
              throw e if e?

              stream.on 'data', (data) ->
                callback  undefined, data.toString()

              .on 'close', (code, signal) ->
                session.end()

              .stderr.on 'data', (data) ->
                callback  stderr: data

              stream.write "#{request_as_json}\n"
              stream.end()
          .connect
            host: hostname
            port: 22
            username: remote_user
            privateKey: fs.readFileSync  path_to_key

      remote = new JsonRpc.Remote  transport, @transcript

      for method in methods
        # This confusing stuff is because "method" will be last element of
        # METHODS when the method is invoked, so instead the current value of
        # method is bound to `this`.
        remote_method_name = "#{@namespace}/#{method}"
        m = ->
          method = @
          # The callback is the last argument
          callback = arguments[arguments.length - 1]

          throw 'The last parameter should be a callback' if typeof callback isnt 'function'

          # All prior arguments should be passed to the server
          params = []
          if 2 <= arguments.length
            for i in [0 .. arguments.length - 2]
              params.push arguments[i]

          remote.invoke_method  remote_method_name, params..., callback

        @[method] = m.bind  method



exports.RemoteHost = RemoteHost

