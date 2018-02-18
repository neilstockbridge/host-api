#!/usr/bin/env coffee

fs = require 'fs'

Client = require('ssh2').Client



p = ->
  console.log.apply  this, arguments



session = new Client()
session.on 'ready', ->
  session.exec 'cat', (e, stream) ->
    throw e if e
    stream.on 'data', (data) ->
      console.log('STDOUT: ' + data)
    .on 'close', (code, signal) ->
      p ending:1
      session.end()
    .stderr.on 'data', (data) ->
      console.log('STDERR: ' + data)

    stream.write 'dog'
    stream.end()
.connect
  host: 'chi'
  port: 22
  username: 'neil'
  privateKey: fs.readFileSync('/home/neil/.ssh/id_rsa')

