
# Getting started

Currently, Host API supports Debian and Ruby although not only can the approach be easily ported to other platforms and operating systems but the approach will work even when the client and the server are based on different platforms and operating systems.


## Installation

    sudo apt-get install  apt-transport-https  ca-certificates
    wget -qO - https://raw.github.com/neilstockbridge/host-api/master/debian/host-api-archive.key | sudo apt-key add -
    sudo wget -O /etc/apt/sources.list.d/host-api-archive.list  https://raw.github.com/neilstockbridge/host-api/master/debian/host-api-archive.list
    apt-get update
    apt-get install host-api
    apt-get clean


## Configuration

The configuration file `/etc/host-api.yml` determines which plugins are available on a particular host.  The plugins are in `/usr/share/host-api/plugins`.

The client depends upon the `PubkeyAuthentication` feature of SSH.  A key pair must be generated and the key authorized on the remote host like this:

    cat <<'.' >> ~/.ssh/authorized_keys
    command="/usr/bin/host-api",from="203.0.113.1",no-agent-forwarding,no-port-forwarding,no-pty,no-X11-forwarding ssh-rsa YOUR-PUB-KEY-HERE automated host management
    .

The authorised client IP address(es) and the public key must be changed in the above of course.


## Testing

    git clone git@github.com:neilstockbridge/host-api.git

..then edit `Ruby/client/test.rb` to reflect your host, remote user and key then:

    ./test.rb

