
# Host API

Host API is a simple library for RPC over SSH.  Some potential uses are:

  + Centralised monitoring and logging of statistics such as temperature, system load or memory usage
  + Checking that clocks across hundreds of hosts are in sync
  + Determining which packages across hundreds of hosts have security updates waiting
  + Integrating systems administration with an Intranet such as helping users to see where all of the disc space on their backup server has gone, or automatically verifying the freshness of backups independently of the backup process

You've already put effort in to deploying and securing SSH (`AllowUsers`, solely `PubkeyAuthentication`, restricted IPs, etc.).  Now leverage that effort to use RPC without having to secure a new transport or install a web server just to use HTTPS.

Here's what it's like to use on the client:

```ruby
rh = HostAPI::RemoteHost.new :hostname => "fine.example.com"
ct = rh.context "com.example.System"
puts ct.system_load
```

 + [How it works](doc/How it works.md)
 + [Getting started](doc/Getting started.md)
 + [Plugins](doc/Plugins.md)
 + [Limitations](doc/Limitations.md)

