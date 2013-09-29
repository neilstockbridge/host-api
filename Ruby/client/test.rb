#!/usr/bin/env ruby

require "host_api"
require "yaml"

rh = HostAPI::RemoteHost.new :hostname => "wet.metaname.net", :remote_user => ENV["USER"], :key => "host-management", :transcript => $stdout
ct = rh.context "com.example.System"
#ct.system_load
puts ct.file_systems.to_yaml

