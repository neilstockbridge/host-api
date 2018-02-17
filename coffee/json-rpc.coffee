


toJSON = ->
  JSON.stringify  @



# A JSON-RPC 2.0 client where the transport is pluggable so I can use SSH as a
# transport.
#

class Exception

  constructor: (@code, @message, @data) ->
    #

  toString: toJSON



# Constructed on the client, represents the server.
#
Remote: class Remote

  # Constructs a new object that can invoke remote methods.
  #
  # @param  transport   An object with a methods:
  #                       next_message_id: String
  #                       request( request_as_json:String, callback:Function(error, response_as_json:String))
  # @param  transcript  An object with these methods:
  #                       request_made( request:String)
  #                       response_received( response:String)
  #                     Can be used to provide a trace of requests and
  #                     responses for debugging or to keep a record of all
  #                     API requests in the database
  #
  constructor: (@transport, @transcript) ->
    #


  invoke_method: (method_name, parameters..., callback) ->
    @send_to_remote  @transport.next_message_id(), method_name, parameters..., callback


  notify: (method_name, parameters..., callback) ->
    @send_to_remote  undefined, method_name, parameters..., callback


  send_to_remote: (id, method_name, parameters..., callback) ->

    request =
      id:       id
      jsonrpc: '2.0'
      method:   method_name
      params:   parameters
      toString: toJSON

    request_as_json = JSON.stringify  request

    @transcript.request_made  request_as_json  if @transcript?

    @transport.request  request_as_json, (e, response_as_json) =>
      throw e if e?
      throw "Expected String, Got #{t}" if (t = typeof response_as_json) isnt 'string'

      try
        response_as_json = response_as_json.trim()
        @transcript.response_received  response_as_json  if @transcript?

        # Check that what comes back from the server is JSON:
        try
          response = JSON.parse  response_as_json
        catch e
          @shit -32603, 'Bad JSON received', response_as_json

        # Check that the ID of the response matches the ID of the request:
        if response.id isnt request.id
          @shit -32603, 'Unexpected message ID', response.id

        # If there was an error on the server..
        if (error = response.error)?
          @shit error.code, error.message, error.data
        else if not response.result?
          @shit -32603, 'Neither result nor error present'

        callback  undefined, response.result
      catch e
        callback  e


  shit: (code, message, data) ->
    throw new Exception  code, message, data



# A transcript that makes a trace of messages sent to and from the remote to
# a given stream.
#
StreamTranscript: class StreamTranscript

  constructor: (@stream) ->
    #

  request_made: (request_as_json) ->
    @stream.write "  >> #{request_as_json}\n"

  response_received: (response_as_json) ->
    @stream.write "  << #{response_as_json}\n"



module.exports=
  Exception:        Exception
  Remote:           Remote
  StreamTranscript: StreamTranscript

