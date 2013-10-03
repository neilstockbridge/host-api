#!/usr/bin/env ruby

require "host_api"
require "yaml"

class Node
  attr_accessor :name, :usage, :children
  def initialize a
    @name, @usage, @children = a
    @children.map! {|c| Node.new c }
  end
end

#rh = HostAPI::RemoteHost.new :hostname => "wet.metaname.net", :remote_user => ENV["USER"], :key => "host-management", :transcript => $stdout
#rh = HostAPI::RemoteHost.new :hostname => "black.safe.org.nz", :remote_user => ENV["USER"], :key => "id_rsa", :transcript => $stdout
rh = HostAPI::RemoteHost.new :hostname => "localhost", :remote_user => ENV["USER"], :key => "id_rsa", :transcript => $stdout
ct = rh.context "com.example.System"
#ct.system_load
#puts ct.file_systems.to_yaml
#root = Node.new ct.disc_usage("/srv/software")
#puts root.to_yaml
puts ct.latest_change_under("/srv/software").to_yaml

