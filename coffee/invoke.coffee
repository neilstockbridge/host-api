#!/usr/bin/env coffee
#
# Invokes a HostAPI method on a remote host.
#

process = require 'process'
JsonRpc = require './json-rpc'
HostAPI = require './host-api'

remote_host = new HostAPI.RemoteHost
  hostname:  'iMX233-nano'
  #port:       2201
  key:       'host-management'
  transcript: new JsonRpc.StreamTranscript process.stdout

remote = remote_host.context 'nz.rui.HomeAutomation', ['watering']

remote.watering 'status', (e, status) ->
  throw e if e?
  console.log  status

