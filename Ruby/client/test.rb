#!/usr/bin/env ruby

require "rubygems"
require "host_api"
require "yaml"

rh = HostAPI::RemoteHost.new :hostname => "localhost", :remote_user => ENV["USER"], :key => "id_rsa", :transcript => $stdout
ct = rh.context "ro.dist.System"
#ct.system_load
puts ct.file_systems.to_yaml

