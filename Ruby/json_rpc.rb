
# Copyright (C) 2011-2013 Neil Stockbridge
# License: GPLv2

require "json"


# Example:
#     transport = MyTransport.new  # OR:
#     transport = lambda {|request_as_json| remote.puts( request_as_json); remote.gets }
#     remote = Remote.new  transport
#     remote.transcript = StreamTranscript.new
#     begin
#       remote.invoke_method :add, [ 2, 3]  #=> 5
#     rescue Error => e
#       # Use e.code, e.message and/or e.data to debug and/or take action
#     end
#
module JsonRpc

  class Error < StandardError

    attr_reader :code, :message, :data

    def initialize code, message, data = nil
      @code = code
      @message = message
      @data = data
    end

  end # of Error


  # Constructed on the client, represents the server.
  #
  class Remote

    # Constructs a new object that can invoke remote methods.
    #
    # @param [Transport] transport is an object with a
    #                              response_to( request_as_json: String): String
    #                              method that returns the response ( as a
    #                              JSON-encoded string) to the given request
    #
    def initialize transport
      @transport = transport
    end


    def transcript
      @transcript ||= NoTranscript.new
    end
    attr_writer :transcript


    def invoke_method method_name, *args
      send_to_remote  transcript.next_message_id, method_name, *args
    end


    def notify method_name, *args
      send_to_remote  nil, method_name, *args
    end


    def send_to_remote id, method_name, *args

      request = {
        :jsonrpc => "2.0",
        :method =>   method_name,
        :params =>   args,
      }
      request[:id] = id if id
      request_as_json = request.to_json

      transcript.request_made  request_as_json

      response_as_json = if transcript.is_recorded
          transcript.next_response
        else
          case @transport
            when Proc
              @transport[ request_as_json]
            else
              @transport.response_to  request_as_json
          end
        end

      transcript.response_received  response_as_json

      # Check that what comes back from the server is JSON:
      begin
        response = JSON.parse response_as_json
      rescue JSON::ParserError
        raise Error.new -32603, "Bad JSON received"
      end

      # Check that the ID of the response matches the ID of the request:
      if not transcript.is_recorded and response["id"] != request[:id]
        raise Error.new -32603, "Unexpected message ID"
      end

      # If there was an error on the server..
      if er = response["error"]
        raise Error.new  er["code"], er["message"], er["data"]
      elsif ! response.has_key? "result"
        raise Error.new  -32603, "Neither result nor error present"
      end

      response["result"]
    end

  end # of Remote


  # Mixed in to the server.
  #
  module Endpoint

    def rpc_response_to request_as_json
      # request: a map with :jsonrpc => "2.0", etc.
      response_to = lambda do |request|
        begin
          # The request might be valid JSON but still not be an "Object", so check for that:
          raise rpc_invalid_request "request must be an Object" unless request.is_a? Hash
          # The "jsonrpc" field MUST be present and must have a value of "2.0"
          raise rpc_invalid_request "jsonrpc field absent" unless request.has_key? "jsonrpc"
          raise rpc_invalid_request "jsonrpc version is incompatible" unless "2.0" == request["jsonrpc"]
          # If the "id" mapping is absent then this request is a "Notification"
          is_notification = ! request.has_key?("id")
          id = request["id"]
          # id MUST be a String, Number ( might be fractional, discouraged) or null ( also discouraged) if included
          raise rpc_invalid_request "invalid id" unless [NilClass, Fixnum, String, Float].include? id.class
          method_name = request["method"]
          raise rpc_invalid_request "method name absent" if method_name.nil?
          # Method names MUST NOT begin with "rpc."
          raise rpc_invalid_request "Method name MUST NOT begin with rpc." if method_name.start_with? "rpc."
          formal_params = rpc_params_of  method_name
          raise Error.new -32601, "Method not found", method_name if formal_params.nil?
          # params MAY be omitted
          params = request["params"] || []
          # params may be list of args, or map of args by name ( MUST match published names)
          case params
            when Array
              # Check that the correct number of parameters have been given:
              raise rpc_invalid_params "Wrong number of params" unless params.count == formal_params.count
            when Hash
              # Check that each named parameter has been supplied and that no
              # spurious parameters have been supplied:
              params_by_name = params
              raise rpc_invalid_params "Wrong number of params" unless params_by_name.count == formal_params.count
              raise rpc_invalid_params "Wrong param names" unless params_by_name.keys.sort == formal_params.sort
              # Replace the map of named params with the values of the params
              # in the order expected by the method:
              params = formal_params.map {|pr| params_by_name[pr] }
            else
              raise rpc_invalid_params
          end

          # Invoke the actual method:
          result = rpc_invoke  method_name, params

          # Notifications return nil:
          #  If batch request is invalid, MUST return SINGLE error ( not array).
          # MUST NOT include responses to Notifications
          if is_notification
            nil
          else
            # id MUST be present and MUST be null if request.id was invalid
            # when the request is granted, "result" MUST be present and "error"
            # MUST NOT be present:
            {:id => id, :result => result }
          end
        # It would have been nice to support any exception that responds to :code
        # but it's inadvisable since there may be exceptions that respond to
        # :code that we don't know about, which might even return arbitrary
        # string values for :code and thus breach protocol
        rescue Error => e
          # if the request was declined then "error" MUST be present and "result"
          # MUST NOT be present:
          error = {:code => e.code }
          error[:message] = e.message if e.message
          error[:data] = e.data if e.data
          {:id => id, :error => error }
        rescue StandardError => e
          # Don't leak details of internal errors
          $stderr.puts e.info
          {:id => id, :error => {:code => -32603, :message => "Internal error"} }
        end
      end

      begin
        data = JSON.parse  request_as_json
        # If this is a BATCH request..
        if data.is_a? Array
          requests = data
          if requests.empty?
            response = {:id => nil, :error => {:code => -32600, :message => "Invalid Request", :data => "Empty batch"} }
          else
            is_batch_request = true
            responses = requests.map {|request| response_to[ request] }
          end
        else
          request = data
          response = response_to[ request]
        end
      rescue JSON::ParserError => e
        # batch_request will be undefined even if the request was a batch
        # request, which results in a single response object, which is correct
        response = {:id => nil, :error => {:code => -32700, :message => "Parse error"} }
      end
      if ! is_batch_request
        response[:jsonrpc] = "2.0" unless response.nil?
        reply = response
      else
        # Remove nil responses, which are from Notifications:
        responses.compact!
        # Automatically include the JSON-RPC version in each response:
        responses.each {|rs| rs[:jsonrpc] = "2.0"}
        reply = responses
      end
      # The server MUST NOT reply to Notifications
      # In BATCH mode nothing should be returned instead of an empty array of responses:
      if reply != nil  &&  reply != []
        reply.to_json
      else
        ""
      end
    end

    # Provides the names of the formal parameters to the specified API method
    # or nil if no such method is available.  This method must be replaced in
    # order to expose API methods.
    #
    def rpc_params_of method_name
      nil
    end

    # Invoked to service a single request.  This is the default implementation
    # which merely invokes the named method on this object passing the parameters
    # as-is although this method may be overridden, perhaps to perform tasks such
    # as logging and authentication in one place for all API methods.
    #
    def rpc_invoke method_name, params
      self.send  method_name, *params
    end


    def rpc_invalid_request data = nil
      Error.new -32600, "Invalid Request", data
    end

    def rpc_invalid_params data = nil
      Error.new -32602, "Invalid params", data
    end

  end # of Endpoint


  # The base class for transcripts, which exists really only to house some
  # shared code.
  #
  class Transcript

    def is_recorded
      false
    end

    def next_message_id
      sleep 0.001 # To ensure the uniqueness of the below id
      now = Time.now
      millis = "%03i"% ( now.usec / 1000)
      now.strftime "%Y%m%d%H%M%S.#{millis}"
    end

  end


  # The default transcript that does nothing.
  #
  class NoTranscript < Transcript

    def request_made request_as_json
      # Do nothing
    end

    def response_received response_as_json
      # Do nothing
    end

  end


  # A transcript that makes a trace of messages sent to and from the remote to
  # a given stream ( stdout by default).
  #
  class StreamTranscript < Transcript

    def initialize stream = $stdout
      @stream = stream
    end

    def request_made request_as_json
      @stream.puts "  >> "+ request_as_json
    end

    def response_received response_as_json
      @stream.puts "  << "+ response_as_json
    end

  end

end # of JsonRpc

