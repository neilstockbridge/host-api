
# Host API

Host API is a simple library that supports using SSH for RPC.  Some examples of use are:

  + Centralised monitoring and logging of statistics such as temperature, system load or memory usage
  + Checking that clocks across hundreds of hosts are in sync
  + Determining which packages across hundreds of hosts have security updates waiting
  + Integrating systems administration with an Intranet such as helping users to see where all of the disc space on their backup server has gone, or automatically verifying the freshness of backups indepdent of the backup process

You've already put effort in to deploying and securing SSH (`AllowUsers`, `PubkeyAuthentication` only, known IPs only, etc.).  Now leverage that effort to use RPC without having to secure a new transport or install a web server just to use HTTPS.

Here's what it's like to use on the client:

    #!ruby
    rh = HostAPI::RemoteHost.new :hostname => "myhost.example.com"
    ct = rh.context "ro.dist.System"
    puts ct.system_load

Currently, Host API supports Debian and Ruby although not only can the approach be easily ported to other platforms and operating systems but the approach will work even when the client and the server are based on different platforms and operating systems.

