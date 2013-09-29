
# How Host API works

The "client" is the code that invokes the remote method while the "host" is the remote host.

 + The client creates a `RemoteHost` object, configured with the name of the remote host on which to invoke the method, the user on the remote host to connect as and the SSH key to use
 + The client creates a `Context` object, which exists only as a pretty way to remember the context within the client process.  Contexts mean that each plugin has its own namespace for methods
 + The client invokes a method on the context object naturally ( as if the method were defined on the context object)
 + HostAPI establishes an SSH connection to the host, logging in as the remote user and offering the key
 + The key has already been authorised by remote user on the host ( with source-IP and `command` restrictions)
 + `host-api` is started by `sshd` on the remote host, which waits for something exciting to appear on its `stdin`
 + HostAPI on the client serializes the method invocation using [JSON-RPC] and writes the serialized form to `stdout` in the SSH session.  The JSON-RPC method name for context `com.example.System` and method `file_systems` is encoded as `com.example.System/file_systems`
 + The remote host unpacks the method invocation, locates the specified plugin, invokes the method and returns the response on its `stdout`
 + HostAPI on the client parses the response and returns real objects ( scalars or arbitrarily complex compositions of lists, maps and scalars as permitted by JSON-RPC)

  [JSON-RPC]: http://www.jsonrpc.org/

