
# Limitations

At present there at least these limitations:

 + A new SSH connection is established for each method invocation, which makes this approach unsuitable for high volume RPC.  This can be mitigated to some extent by enabling SSH connection persistence and re-use with `ControlMaster`.  The server-side code is also capable of handling a series of requests without spawning a new process although there is no support for this on the client side presently
 + Only Debian and Ruby are supported, although the concept is so trivial that adding support for other platforms on either the client-side, server-side or both is straightforward
 + There is no fine-grained access control.  If a client has the required key and a plugin is enabled on a host then that client may invoke methods on that plugin

