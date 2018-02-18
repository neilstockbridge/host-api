#!/usr/bin/env coffee

JsonRpc = require './json-rpc'



p = ->
  console.log.apply  this, arguments



tests = 0
passes = 0



# Produces a String like:
#
#   'id 1  jsonrpc "2.0"  method "ping"  params [1,2]'
#
to_s = (value) ->
  if typeof value is 'object'
    properties = Object.keys  value
    properties.sort()
    properties.map (property) ->
      "#{property} #{JSON.stringify value[property]}"
    .join '  '
  else
    String.valueOf  value



should_be_equal = (expected, got) ->
  tests += 1
  if got is expected
    passes += 1
  else
    p new Error("Expected\n#{expected}\nbut got\n#{got}").stack



should_have_thrown = ->
  p new Error("Should have thrown Exception but didn't").stack



test = ->


  transport =

    message_id: 0

    next_message_id: ->
      @message_id += 1

    request: (request_as_json, callback) ->
      callback undefined, @response_to_provide

    simulate_result: (result) ->
      @response_to_provide = JSON.stringify
        jsonrpc: '2.0'
        id:       @message_id + 1
        result:   result

    simulate_error: (code, message, data) ->
      @response_to_provide = JSON.stringify
        jsonrpc: '2.0'
        id:       @message_id + 1
        error:
          code:    code
          message: message
          data:    data


  transcript =

    request_made: (@request_made_as_json) ->
      @request_as_s= to_s JSON.parse @request_made_as_json

    response_received: (response_as_json) ->
      #
      #p response_as_json

    check_invocation: (method_name, params) ->
      expected= to_s jsonrpc: '2.0', id: transport.message_id, method: method_name, params: params
      should_be_equal  expected,  transcript.request_as_s

    check_notice: (method_name, params) ->
      expected= to_s jsonrpc: '2.0', method: method_name, params: params
      should_be_equal  expected,  transcript.request_as_s


  remote = new JsonRpc.Remote  transport, transcript

  check_exception = (e, code, message, data) ->
    should_be_equal  code, e.code
    should_be_equal  message, e.message
    should_be_equal  to_s(data), to_s(e.data)

  # Bad JSON
  try
    transport.response_to_provide = '['
    remote.invoke_method 'ping', (e, result) ->
      throw e if e?
      should_have_thrown()
  catch e
    check_exception  e, -32603, 'Bad JSON received', '['

  # Mismatched request ID
  try
    transport.response_to_provide = '{"jsonrpc":"2.0", "id":0}'
    remote.invoke_method 'ping', (e, result) ->
      throw e if e?
      should_have_thrown()
  catch e
    check_exception  e, -32603, 'Unexpected message ID', 0

  # Neither error not result present
  try
    transport.response_to_provide = "{\"jsonrpc\":\"2.0\", \"id\":#{transport.message_id + 1}}"
    remote.invoke_method 'ping', (e, result) ->
      throw e if e?
      should_have_thrown()
  catch e
    check_exception  e, -32603, 'Neither result nor error present'

  # Server error
  data = age:'should be a number', password:'too short'
  try
    transport.simulate_error 1, 'Validation Error', data
    remote.invoke_method 'join', (e, result) ->
      throw e if e?
      should_have_thrown()
  catch e
    check_exception  e, 1, 'Validation Error', data

  # Success
  transport.simulate_result 0.4
  result = remote.invoke_method 'add', 1, 2, (e, result) ->
    throw e if e?
    transcript.check_invocation 'add', [1, 2]
    should_be_equal  0.4, result

  #result = remote.notify 'notice', true, one:'one'  # Check no ID
  #transcript.check_notify 'notice', [true, {one:'one'}]
  #should_be_equal  null, result

  p "#{passes} of #{tests} tests passed"


test()

