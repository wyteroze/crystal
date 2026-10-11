const c = @import("c");
const errors = @import("errors.zig");
const properties = @import("properties.zig");
const std = @import("std");

comptime {
    if (!@hasDecl(c, "NET_Quit"))
        @compileError("The ext_net feature is either not enabled or not working!");
}

/// Opaque representation of a computer-readable network address.
///
/// ## Remarks
/// This is an opaque datatype, to be treated by the app as a handle.
///
/// SDL net uses these to identify other servers; you use them to connect to a remote machine, and you use them to find out who connected to you.
/// They are also used to decide what network interface to use when creating a server.
///
/// These are intended to be protocol-independent; a given address might be for IPv4, IPv6, or something more esoteric.
/// SDL net attempts to hide the differences.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const Address = extern struct {
    value: *c.NET_Address,

    comptime {
        std.debug.assert(@sizeOf(Address) == @sizeOf(*c.NET_Address));
    }

    /// Compare two `Address` objects.
    ///
    /// ## Function Parameters
    /// * `self`: The first address to compare.
    /// * `other`: second address to compare.
    ///
    /// ## Return Value
    /// Returns `std.math.Order.lt` if `self` is "less than" `other`, `std.math.Order.gt` if "greater than", `std.math.Order.eq` if equal.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn compare(
        self: Address,
        other: Address,
    ) std.math.Order {
        return std.math.order(c.NET_CompareAddresses(self.value, other.value), 0);
    }

    /// Get the protocol-level bytes of a network address from a resolved address.
    ///
    /// ## Function Parameters
    /// * `self`: The address to query.
    ///
    /// ## Remarks
    /// This data is not human-readable, is protocol-specific, and might not even be in a specific byte order.
    ///
    /// This is only useful for possibly hashing, to map a address to a specific player in a game,
    /// or possibly for handing to a system-level networking API (which is not recommended; an app does this at their own risk).
    ///
    /// Do not store these bytes for future runs of the program; there is no promise the format won't change.
    ///
    /// Do not free or modify the returned data; it belongs to the `Address` that was queried, and is valid as long as the object lives.
    /// Either make sure the address has a reference as long as you need this or make a copy of the bytes.
    ///
    /// This will return an error if resolution is still in progress, or if resolution failed.
    /// You can use `Address.getStatus` or `Address.waitUntilResolved` to make sure resolution has successfully completed before calling this.
    ///
    /// A human-readable version is available in `Address.getString` and isn't any less efficient to query than the raw bytes.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getBytes(
        self: Address,
    ) ![]const u8 {
        var num_bytes: c_int = undefined;
        const bytes: [*]const u8 = @ptrCast(@alignCast(try errors.wrapCallNull(*const anyopaque, c.NET_GetAddressBytes(self.value, &num_bytes))));
        return bytes[0..@intCast(num_bytes)];
    }

    /// Check if an address is resolved, without blocking.
    ///
    /// ## Function Parameters
    /// * `self`: The address to query.
    ///
    /// ## Return Value
    /// Returns `Status.success` if successfully resolved, `Status.waiting` if still resolving.
    ///
    /// ## Rermarks
    /// The `Address` objects returned by `Address.resolveHostname` take time to do their work, so it does so asynchronously instead of making your program wait an indefinite amount of time.
    ///
    /// This function allows you to check the progress of that work without blocking.
    ///
    /// Resolution can fail after some time (DNS server took awhile to reply that the hostname isn't recognized, etc),
    /// so be sure to check the result of this function instead of assuming it worked because it's non-zero!
    ///
    /// Once an address is successfully resolved, it can be used to connect to the host represented by the address.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getStatus(
        self: Address,
    ) !Status {
        return Status.fromSdl(c.NET_GetAddressStatus(self.value));
    }

    /// Get a human-readable string from a resolved address.
    ///
    /// ## Function Parameters
    /// * `self`: The address to query.
    ///
    /// ## Return Value
    /// Returns a string, or `null` on error or if not yet resolved.
    ///
    /// ## Remarks
    /// This returns a string that's "human-readable", in that it's probably a string of numbers and symbols, like "159.203.69.7" or "2604:a880:800:a1::71f:3001".
    /// It won't be the original hostname (like "icculus.org"), but it's suitable for writing to a log file, etc.
    ///
    /// Do not free or modify the returned string; it belongs to the `Address` that was queried, and is valid as long as the object lives.
    /// Either make sure the address has a reference as long as you need this or make a copy of the string.
    ///
    /// This will return `null` if resolution is still in progress, or if resolution failed.
    /// You can use `Address.getStatus` or `Address.waitUntilResolved` to make sure resolution has successfully completed before calling this.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getString(
        self: Address,
    ) ?[:0]const u8 {
        const ret = c.NET_GetAddressString(self.value);
        if (ret == null)
            return null;
        return std.mem.span(ret);
    }

    /// Resolve a human-readable hostname.
    ///
    /// ## Function Parameters
    /// * `host`: The hostname to resolve.
    ///
    /// ## Return Value
    /// Returns a new address on success.
    ///
    /// ## Remarks
    /// SDL net doesn't operate on human-readable hostnames (like www.libsdl.org but on computer-readable addresses.
    /// This function converts from one to the other.
    /// This process is known as "resolving" an address.
    ///
    /// You can also use this to turn IP address strings (like "159.203.69.7") into `Address` objects.
    ///
    /// Note that resolving an address is an asynchronous operation, since the library will need to ask a server on the internet to get the information it needs,
    /// and this can take time (and possibly fail later).
    /// This function will not block.
    /// Until the address resolves, it can't be used.
    ///
    /// If you want to block until the resolution is finished, you can call `Address.waitUntilResolved`.
    /// Otherwise, you can do a non-blocking check with `Address.getStatus`.
    ///
    /// When you are done with the returned `Address`, call `Address.unref` to dispose of it.
    /// You need to do this even if resolution later fails asynchronously.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn init(
        host: [:0]const u8,
    ) !Address {
        return .{
            .value = try errors.wrapCallNull(*c.NET_Address, c.NET_ResolveHostname(host.ptr)),
        };
    }

    /// Add a reference to an `Address`.
    ///
    /// ## Function Parameters
    /// * `self`: The address to add a reference to.
    ///
    /// ## Return Value
    /// Returns the same address that was passed as a parameter.
    ///
    /// ## Remarks
    /// Since several pieces of the library might share a single `Address`, including a background thread that's working on resolving, these objects are referenced counted.
    /// This allows everything that's using it to declare they still want it, and drop their reference to the address when they are done with it.
    /// The object's resources are freed when the last reference is dropped.
    ///
    /// This function adds a reference to an `Address`, increasing its reference count by one.
    ///
    /// The documentation will tell you when the app has to explicitly unref an address.
    /// For example, `Address.resolveHostname` creates addresses that are already referenced, so the caller needs to unref it when done.
    ///
    /// Generally you only have to explicit ref an address when you have different parts of your own app that will be sharing an address.
    /// In normal usage, you only have to unref things you've created once (like you might free() something), but you are free to add extra refs if it makes sense.
    ///
    /// This returns the same address passed as a parameter, which makes it easy to ref and assign in one step:
    /// ```zig
    /// const myAddr = yourAddr.ref();
    /// ```
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn ref(
        self: Address,
    ) !Address {
        return .{ .value = try errors.wrapCallNull(*c.NET_Address, c.NET_RefAddress(self.value)) };
    }

    /// Drop a reference to an `Address`.
    ///
    /// ## Function Parameters
    /// * `self`: The address to drop a reference to.
    ///
    /// ## Remarks
    /// Since several pieces of the library might share a single `Address`, including a background thread that's working on resolving, these objects are referenced counted.
    /// This allows everything that's using it to declare they still want it, and drop their reference to the address when they are done with it.
    /// The object's resources are freed when the last reference is dropped.
    ///
    /// This function drops a reference to an `Address`, decreasing its reference count by one.
    ///
    /// The documentation will tell you when the app has to explicitly unref an address.
    /// For example, `Address.resolveHostname` creates addresses that are already referenced, so the caller needs to unref it when done.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn unref(
        self: Address,
    ) void {
        c.NET_UnrefAddress(self.value);
    }

    /// Block until an address is resolved.
    ///
    /// ## Function Parameters
    /// * `self`: The address object to wait on.
    /// * `timeout`: The maximum time to wait for resolution to complete.
    ///
    /// ## Return Value
    /// Returns the connection status.
    ///
    /// ## Remarks
    /// The `Address` objects returned by `Address.resolveHostname` take time to do their work,
    /// so it does so asynchronously instead of making your program wait an indefinite amount of time.
    ///
    /// However, if you want your program to sleep until the address resolution is complete, you can call this function.
    ///
    /// This function takes a timeout value, represented in milliseconds, of how long to wait for resolution to complete.
    ///
    /// Resolution can fail after some time (DNS server took awhile to reply that the hostname isn't recognized, etc),
    /// so be sure to check the result of this function instead of assuming it worked!
    ///
    /// Once an address is successfully resolved, it can be used to connect to the host represented by the address.
    ///
    /// If you don't want your program to block, you can call `Address.getStatus` from time to time until you get a non-zero result.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread, and several threads can block on the same address simultaneously.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn waitUntilResolved(
        self: Address,
        timeout: Timeout,
    ) !Status {
        const ret = c.NET_WaitUntilResolved(self.value, timeout.toSdl());
        return Status.fromSdl(ret);
    }
};

/// The data provided for new incoming packets from `DatagramSocket.receive`.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const Datagram = extern struct {
    /// Sender's address. This is unref'd by `Datagram.deinit`.
    /// You only need to ref it if you want to keep it.
    addr: Address,
    /// Sender's port.
    /// These do not have to come from the same port the receiver is bound to.
    /// These are in host byte order, don't byteswap them!
    port: u16,
    /// The payload of this datagram.
    buf: [*]u8,
    /// The number of bytes available at `buf`.
    buf_len: c_int,

    comptime {
        errors.assertStructsEqual(@This(), c.NET_Datagram);
    }

    /// Dispose of a datagram packet previously received.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram to destroy.
    ///
    /// ## Remarks
    /// You must pass packets received through `Datagram.receive` to this function when you are done with them.
    /// This will free resources used by this packet and unref its `Address`.
    ///
    /// If you want to save the sender's address from the packet past this time, it is safe to call `Address.ref` on the address and hold onto its pointer,
    /// so long as you call `Address.unref` on it when you are done with it.
    ///
    /// Once you call this function, the datagram pointer becomes invalid and should not be used again by the app.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(
        self: *Datagram,
    ) void {
        c.NET_DestroyDatagram(@ptrCast(@alignCast(self)));
    }

    /// Get the data payload of the datagram.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram to get the data from.
    ///
    /// ## Remarks
    /// The returned slice is owned by the datagram and is valid until `deinit()` is called.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getData(
        self: Datagram,
    ) []const u8 {
        return self.buf[0..@intCast(self.buf_len)];
    }
};

/// An object that represents a datagram connection to another system.
///
/// ## Remarks
/// This is meant to be an unreliable, packet-oriented connection, such as UDP.
///
/// Datagram sockets follow different rules than stream sockets.
/// They are not a reliable stream of bytes but rather packets, they are not limited to talking to a single other remote system,
/// they do not maintain a single "connection" that can be dropped, and they are more nimble about network failures at the expense of being more complex to use.
/// What makes sense for your app depends entirely on what your app is trying to accomplish.
///
/// Generally the idea of a datagram socket is that you send data one chunk ("packet") at a time to any address you want,
/// and it arrives whenever it gets there, even if later packets get there first, and maybe it doesn't get there at all, and you don't know when anything of this happens by default.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const DatagramSocket = extern struct {
    value: *c.NET_DatagramSocket,

    comptime {
        std.debug.assert(@sizeOf(DatagramSocket) == @sizeOf(*c.NET_DatagramSocket));
    }

    /// Initialization properties for the datagram socket.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    const InitProperties = struct {
        /// True if the socket should be created even if a previous socket has recently used this address.
        /// For various reasons, networks prefer that there be some delay between apps reusing the same address, but this can be problematic when iterating quickly,
        /// for software development purposes or just restarting a crashed service.
        /// This property defaults to `true` (although it should be noted that, at the operating system level, this defaults to `false`!).
        /// If this property is `false` and the OS feels that not enough time has elapsed, socket creation will fail and the `DatagramSocket.init` function will report an error.
        reuse_addr: ?bool = null,
        /// True if the socket should allow broadcasting.
        /// At the lower level, this will set `SO_BROADCAST` for IPv4 sockets, to allow sending to the subnet's broadcast address at the OS level.
        /// For IPv6, it'll join the all-nodes link-local multicast group, `ff02::1`, allowing sending and receiving there,
        /// more or less simulating the usual IPv4 broadcast semantics.
        /// Other protocols take similar approaches.
        /// If you do not intend to send or receive broadcast packets on this socket, set this property to `false`, or omit it, as it defaults to `false`.
        /// Note: IPv4 will still be able to receive broadcast packets without this option, but IPv6 will not.
        /// Also see notes about sending to a broadcast address in `DatagramSocket.send`.
        allow_broadcast: ?bool = null,

        /// Convert to an SDL properties group.
        pub fn toProperties(
            self: InitProperties,
        ) !properties.Group {
            const ret = try properties.Group.init();
            if (self.reuse_addr) |val| try ret.set(
                c.NET_PROP_DATAGRAM_SOCKET_REUSEADDR_BOOLEAN,
                .{ .boolean = val },
            );
            if (self.allow_broadcast) |val| try ret.set(
                c.NET_PROP_DATAGRAM_SOCKET_ALLOW_BROADCAST_BOOLEAN,
                .{ .boolean = val },
            );
            return ret;
        }
    };

    /// Dispose of a previously-created datagram socket.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to destroy.
    ///
    /// ## Remarks
    /// This will abandon any data queued for sending that hasn't made it to the socket.
    /// If you need this data to arrive, you should wait for confirmation from the remote computer in some form that you devise yourself.
    /// Queued data is not guaranteed to arrive even if the library made efforts to transmit it here.
    ///
    /// Any data that has arrived from the remote end of the connection that hasn't been read yet is lost.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(
        self: DatagramSocket,
    ) void {
        c.NET_DestroyDatagramSocket(self.value);
    }

    /// Create and bind a new datagram socket.
    ///
    /// ## Function Parameters
    /// * `addr`: the local address to listen for connections on, or `null` to listen on all available local addresses.
    /// * `port`: the port on the local address to listen for connections on, or zero for the system to decide.
    /// * `props`: Properties for the new socket.
    ///
    /// ## Return Value
    /// Returns a new `DatagramSocket`.
    ///
    /// ## Remarks
    /// Datagram sockets follow different rules than stream sockets.
    /// They are not a reliable stream of bytes but rather packets, they are not limited to talking to a single other remote system,
    /// they do not maintain a single "connection" that can be dropped, and they are more nimble about network failures at the expense of being more complex to use.
    /// What makes sense for your app depends entirely on what your app is trying to accomplish.
    ///
    /// Generally the idea of a datagram socket is that you send data one chunk ("packet") at a time to any address you want, and it arrives whenever it gets there,
    /// even if later packets get there first, and maybe it doesn't get there at all, and you don't know when anything of this happens by default.
    ///
    /// This function creates a new datagram socket.
    ///
    /// This function does not block, and is not asynchronous, as the system can decide immediately if it can create a socket or not.
    /// If this returns success, you can immediately start talking to the network.
    ///
    /// You can specify an address to listen for connections on; this address must be local to the system, and probably one returned by `getLocalAddresses`,
    /// but almost always you just want to specify `null` here, to listen on any address available to the app.
    ///
    /// If you need to bind to a specific port (like a server), you should specify it in the port argument; datagram servers should do this,
    /// so they can be reached at a well-known port.
    /// If you only plan to initiate communications (like a client), you should specify 0 and let the system pick an unused port.
    /// Only one process can bind to a specific port at a time, so if you aren't acting as a server, you should choose `0`.
    /// Datagram sockets can send individual packets to any port, so this just declares where data will arrive for your socket.
    ///
    /// Datagram sockets don't employ any protocol (above the UDP level), so they can talk to apps that aren't using SDL net,
    /// but if you want to speak any protocol beyond arbitrary packets of bytes, such as WebRTC, you'll have to implement that yourself on top of the stream socket.
    ///
    /// Unlike BSD sockets or WinSock, you specify the port as a normal integer; you do not have to byteswap it into "network order," as the library will handle that for you.
    ///
    /// The caller may supply properties to customize behavior.
    /// This is optional, and a value of `null` for props will request defaults for all properties.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn init(
        addr: ?Address,
        port: u16,
        props: ?InitProperties,
    ) !DatagramSocket {
        const group = if (props) |val| try val.toProperties() else null;
        defer if (group) |val| val.deinit();

        return .{
            .value = try errors.wrapCallNull(*c.NET_DatagramSocket, c.NET_CreateDatagramSocket(if (addr) |val| val.value else null, port, if (group) |val| val.value else 0)),
        };
    }

    /// Receive a new packet that a remote system sent to a datagram socket.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to receive data from.
    ///
    /// ## Return Value
    /// Returns a new datagram packet if one was available, `null` otherwise.
    /// The caller must call `Datagram.deinit` on the returned datagram when done with it.
    ///
    /// ## Remarks
    /// Datagram sockets send packets of data.
    /// They either arrive as complete packets or they don't arrive at all, so you'll never receive half a packet.
    ///
    /// This call never blocks; if no new data is available at the time of the call, it returns immediately.
    /// The caller can try again later.
    ///
    /// On a successful call to this function, it returns, even if no new packets are available.
    ///
    /// You must pass received packets to `Datagram.deinit` when you are done with them.
    /// If you want to save the sender's address past this time, it is safe to call `Address.ref` on the address and hold onto the pointer,
    /// so long as you call `Address.unref` on it when you are done with it.
    ///
    /// Since datagrams can arrive from any address or port on the network without prior warning,
    /// this information is available in the `Datagram` object that is provided by this function, and this is the only way to know who to reply to.
    /// Even if you aren't acting as a "server," packets can still arrive at your socket if someone sends one.
    ///
    /// If there's a fatal error, this function will error.
    /// Datagram sockets generally won't report failures, because there is no state like a "connection" to fail at this level,
    /// but may report failure for unrecoverable system-level conditions; once a datagram socket fails,
    /// you should assume it is no longer usable and should destroy it with `DatagramSocket.deinit`.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn receive(
        self: DatagramSocket,
    ) !?*Datagram {
        var ret: [*c]c.NET_Datagram = undefined;
        try errors.wrapCallBool(c.NET_ReceiveDatagram(self.value, &ret));
        if (ret == null)
            return null;
        return @ptrCast(@alignCast(ret));
    }

    /// Send a new packet over a datagram socket to a remote system.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to send data through.
    /// * `address`: The destination address.
    /// * `port`: The destination port.
    /// * `data`: The data to send as a single packet.
    ///
    /// ## Remarks
    /// Datagram sockets send packets of data.
    /// They either arrive as complete packets or they don't arrive at all,
    /// as opposed to stream sockets, where individual bytes might trickle in as they attempt to reliably deliver a stream of data.
    ///
    /// Datagram packets might arrive in a different order than you sent them, or they may just be lost while travelling across the network.
    /// You have to plan for this.
    /// As an added confusion, since SDL net might send the same packet on multiple interfaces, you might get duplicate packets, possibly from different network addresses.
    /// You have to plan for this, too.
    ///
    /// You can send to any address and port on the network, but there has to be a datagram socket waiting for the data on the other side for the packet not to be lost.
    ///
    /// General wisdom is that you shouldn't send a packet larger than `1500` bytes over the Internet, as bad routers might fragment or lose larger ones,
    /// but this limit is not hardcoded into SDL net and in good conditions you might be able to send significantly more.
    ///
    /// This call never blocks; if it can't send the data immediately, the library will queue it for later transmission.
    /// There is no query to see what is still queued, as datagram transmission is unreliable, so you should never assume anything about queued data.
    ///
    /// If there's a fatal error, this function will return false.
    /// Datagram sockets generally won't report failures, because there is no state like a "connection" to fail at this level,
    /// but may report failure for unrecoverable system-level conditions; once a datagram socket fails,
    /// you should assume it is no longer usable and should destroy it with `DatagramSocket.deinit`.
    ///
    /// Sending to a `null` address is treated as a request to broadcast a packet.
    /// Note that this will report failure immediately if the socket was not created with broadcast permission.
    /// Broadcast packets are (more or less) sent to every machine on the LAN, unconditionally.
    ///
    /// WARNING: It is possible to build a game where everyone is playing on the same LAN, and every player is simply broadcasting packets.
    /// This is absolutely the wrong thing to do, however.
    /// Broadcast packets go to every device on the LAN, whether they want them or not.
    /// The game DOOM, in its heyday, was capable of bringing entire networks to their knees, as many players on the same network would all be broadcasting relentlessly.
    ///
    /// In practice, broadcasting sparingly can be useful for certain functionality: a LAN-only client broadcasting a few packets to ask for available servers,
    /// and running servers replying directly to that client without broadcasting at all, is reasonable and safe.
    /// Once clients and servers have found each other, they can communicate directly without any broadcasting at all.
    /// For peer-to-peer games, once connection is established, it's better to either send unique packets to each known player, or use a multicasting (which works like broadcast,
    /// but only routes packets to devices that are explicitly listening for it).
    ///
    /// With IPv6, which doesn't support broadcasts, broadcasting is faked with multicast to the all-nodes link-local multicast group, `ff02::1`,
    /// either on a specific interface or letting the OS choose the default.
    /// Other protocols might fake broadcast operations in similar ways in the future.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn send(
        self: DatagramSocket,
        address: ?Address,
        port: u16,
        data: []const u8,
    ) !void {
        return errors.wrapCallBool(c.NET_SendDatagram(self.value, if (address) |val| val.value else null, port, data.ptr, @intCast(data.len)));
    }

    /// Enable simulated datagram socket failures.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to set a failure rate on.
    /// * `percent_loss`: A number between `0` and `100`. Higher means more failures. Zero to disable.
    ///
    /// ## Remarks
    /// Often times, testing a networked app on your development machine--which might have a wired connection to a fast,
    /// reliable network service--won't expose bugs that happen when networks intermittently fail in the real world, when the wifi is flakey and firewalls get in the way.
    ///
    /// This function allows you to tell the library to pretend that some percentage of datagram socket data transmission will fail.
    ///
    /// The library will randomly lose packets (both incoming and outgoing) at an average matching `percent_loss`.
    /// Setting this to zero (the default) will disable the simulation.
    /// Setting to `100` means everything fails unconditionally and no further data will get through.
    /// At what percent the system merely borders on unusable is left as an exercise to the app developer.
    ///
    /// This is intended for debugging purposes, to simulate real-world conditions that are various degrees of terrible.
    /// You probably should not call this in production code, where you'll likely see real failures anyhow.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn simulatePacketLoss(
        self: DatagramSocket,
        percent_loss: u7,
    ) void {
        std.debug.assert(percent_loss <= 100);
        c.NET_SimulateDatagramPacketLoss(self.value, @intCast(percent_loss));
    }
};

/// A list of local addresses returned by `getLocalAddresses`.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub const LocalAddressList = struct {
    addresses: []Address,

    /// Free the list of local addresses.
    ///
    /// ## Function Parameters
    /// * `self`: The list to deinitialize.
    ///
    /// ## Remarks
    /// This will unref all addresses in the array and free the array itself.
    ///
    /// Since addresses are reference counted, it is safe to keep any addresses you want from this array even after calling this function,
    /// as long as you called `Address.ref` on them first.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    pub fn deinit(
        self: LocalAddressList,
    ) void {
        c.NET_FreeLocalAddresses(@ptrCast(@alignCast(self.addresses.ptr)));
    }
};

/// A socket that can be polled for input.
///
/// ## Version
/// This type is provided by zig-sdl3.
pub const Pollable = extern union {
    /// Reports new input when a connection is ready to be accepted with `StreamSocket.accept`.
    server: Server,
    /// Reports new input when the remote end has sent more bytes of data to be read with `StreamSocket.read`, or if the socket finished making its initial connection.
    stream: StreamSocket,
    /// Reports new input when a new packet arrives that can be read with `Datagram.receive`.
    datagram: DatagramSocket,

    comptime {
        std.debug.assert(@sizeOf(Pollable) == @sizeOf(*c.NET_Server));
    }
};

/// The receiving end of a stream connection.
///
/// ## Remarks
/// This is an opaque datatype, to be treated by the app as a handle.
///
/// Internally, this is what BSD sockets refers to as a "listen socket".
/// Clients attempt to connect to a server, and if the server accepts the connection, will provide the app with a stream socket to send and receive data over that connection.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const Server = extern struct {
    value: *c.NET_Server,

    comptime {
        std.debug.assert(@sizeOf(Server) == @sizeOf(*c.NET_Server));
    }

    /// Initialization properties for the server.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    const InitProperties = struct {
        /// True if the server should be created even if a previous server has recently used this address.
        /// For various reasons, networks prefer that there be some delay between apps reusing the same address, but this can be problematic when iterating quickly,
        /// for software development purposes or just restarting a crashed service.
        /// This property defaults to `true` (although it should be noted that, at the operating system level, this defaults to `false`!).
        /// If this property is `false` and the OS feels that not enough time has elapsed, server creation will fail and the `Server.init` function will report an error.
        reuse_addr: ?bool = null,

        /// Convert to an SDL properties group.
        pub fn toProperties(
            self: InitProperties,
        ) !properties.Group {
            const ret = try properties.Group.init();
            if (self.reuse_addr) |val| try ret.set(
                c.NET_PROP_SERVER_REUSEADDR_BOOLEAN,
                .{ .boolean = val },
            );
            return ret;
        }
    };

    /// Dispose of a previously-created server.
    ///
    /// ## Function Parameters
    /// * `self`: The server to destroy.
    ///
    /// ## Remarks
    /// This will immediately disconnect any pending client connections that had not yet been accepted,
    /// but will not disconnect any existing accepted connections (which can still be used and must be destroyed separately).
    /// Further attempts to make new connections to this server will fail on the client side.
    ///
    /// ## Thread Safety
    /// You should not operate on the same server from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different servers at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(
        self: Server,
    ) void {
        c.NET_DestroyServer(self.value);
    }

    /// Create a server, which listens for connections to accept.
    ///
    /// ## Function Parameters
    /// * `addr`: The local address to listen for connections on, or `null`.
    /// * `port`: the port on the local address to listen for connections on.
    /// * `props`: Properties of the new server. Specify `null` for defaults.
    ///
    /// ## Return Value
    /// Returns a new `Server`.
    ///
    /// ## Remarks
    /// An app that initiates connection to a remote computer is called a "client", and the thing the client connects to is called a "server".
    ///
    /// Servers listen for and accept connections from clients, which spawns a new stream socket on the server's end, which it can then send/receive data on.
    ///
    /// Use this function to create a server that will accept connections from other systems.
    ///
    /// This function does not block, and is not asynchronous, as the system can decide immediately if it can create a server or not.
    /// If this returns success, you can immediately start accepting connections.
    ///
    /// You can specify an address to listen for connections on; this address must be local to the system, and probably one returned by `getLocalAddresses`,
    /// but almost always you just want to specify `null` here, to listen on any address available to the app.
    ///
    /// After creating a server, you get stream sockets to talk to incoming client connections by calling `Server.accept`.
    ///
    /// Stream sockets don't employ any protocol (above the TCP level), so they can accept connections from clients that aren't using SDL net,
    /// but if you want to speak any protocol beyond an abritrary stream of bytes, such as HTTP, you'll have to implement that yourself on top of the stream socket.
    ///
    /// Unlike BSD sockets or WinSock, you specify the port as a normal integer; you do not have to byteswap it into "network order," as the library will handle that for you.
    ///
    /// The caller may supply properties to customize behavior.
    /// This is optional, and a value of `null` for props will request defaults for all properties.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn init(
        addr: ?Address,
        port: u16,
        props: ?InitProperties,
    ) !Server {
        const group = if (props) |val| try val.toProperties() else null;
        defer if (group) |val| val.deinit();

        return .{
            .value = try errors.wrapCallNull(*c.NET_Server, c.NET_CreateServer(if (addr) |val| val.value else null, port, if (group) |val| val.value else 0)),
        };
    }

    /// Create a stream socket for the next pending client connection.
    ///
    /// ## Function Parameters
    /// * `self`: The server object to check for pending connections.
    ///
    /// ## Return Value
    /// Returns a new stream socket if a connection was pending, `null` otherwise.
    ///
    /// ## Remarks
    /// When a client connects to a server, their connection will be pending until the server accepts the connection.
    /// Once accepted, the server will be given a stream socket to communicate with the client, and they can send data to, and receive data from, each other.
    ///
    /// Unlike `StreamSocket.initClient`, stream sockets returned from this function are already connected and do not have to wait for the connection to complete,
    /// as server acceptance is the final step of connecting.
    ///
    /// This function does not block.
    /// In fact, this function should be called in a loop until the result is `null`, so all pending connections are accepted in a single batch.
    ///
    /// If you want the server to sleep until there's a new connection, you can use `waitUntilInputAvailable`.
    ///
    /// When done with the newly-accepted client, you can disconnect and dispose of the stream socket by calling `StreamSocket.deinit`.
    ///
    /// ## Thread Safety
    /// You should not operate on the same server from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different servers at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn accept(
        self: Server,
    ) !?StreamSocket {
        var ret: ?*c.NET_StreamSocket = undefined;
        try errors.wrapCallBool(c.NET_AcceptClient(self.value, &ret));
        if (ret) |val|
            return .{ .value = val };
        return null;
    }
};

/// State for asynchronous operations.
///
/// ## Remarks
/// Lots of tasks in SDL_net are asynchronous, as they can't complete until data passes over a network at some murky future point in time.
///
/// This includes sending data over a stream socket, resolving a hostname, connecting to a remote system, and other tasks.
///
/// The library never blocks on tasks that take time to complete, with the exception of functions named "Wait", which are intended to do nothing but block until a task completes.
/// Functions that are attempting to do something that might block, or are querying the status of a task in-progress, will return a `Status`,
/// so an app can see if a task completed, and its final outcome.
///
/// ## Version
/// This enum is available since SDL_net 3.0.0.
pub const Status = enum(c.NET_Status) {
    waiting = c.NET_WAITING,
    success = c.NET_SUCCESS,

    /// Convert from an SDL value.
    pub fn fromSdl(
        value: c.NET_Status,
    ) !Status {
        if (value == -1) {
            errors.callErrorCallback();
            return error.SdlError;
        }
        return @enumFromInt(value);
    }

    /// Convert to an SDL value.
    pub fn toSdl(
        self: Status,
    ) c.NET_Status {
        return @intFromEnum(self);
    }
};

/// An object that represents a streaming connection to another system.
///
/// ## Remarks
/// This is meant to be a reliable, stream-oriented connection, such as TCP.
///
/// Each `StreamSocket` represents a single connection between systems.
/// Usually, a client app will have one connection to a server app on a different computer, and the server app might have many connections from different clients.
/// Each of these connections communicate over a separate stream socket.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const StreamSocket = extern struct {
    value: *c.NET_StreamSocket,

    comptime {
        std.debug.assert(@sizeOf(StreamSocket) == @sizeOf(*c.NET_StreamSocket));
    }

    /// Initialization properties.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    const InitProperties = struct {};

    /// Dispose of a previously-created stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to destroy.
    ///
    /// ## Remarks
    /// This will immediately disconnect the other side of the connection, if necessary.
    /// Further attempts to read or write the socket on the remote end will fail.
    ///
    /// This will abandon any data queued for sending that hasn't made it to the socket.
    /// If you need this data to arrive, you should wait for it to transmit before destroying the socket with `StreamSocket.getPendingWrites` or `StreamSocket.waitUntilDrained`.
    /// Any data that has arrived from the remote end of the connection that hasn't been read yet is lost.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(
        self: StreamSocket,
    ) void {
        c.NET_DestroyStreamSocket(self.value);
    }

    /// Get the remote address of a stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to query.
    ///
    /// ## Return Value
    /// Returns the socket's remote address.
    ///
    /// ## Remarks
    /// This reports the address of the remote side of a stream socket, which might still be pending connnection.
    ///
    /// This adds a reference to the address; the caller must call `Address,unref` when done with it.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getAddress(
        self: StreamSocket,
    ) !Address {
        return .{
            .value = try errors.wrapCallNull(*c.NET_Address, c.NET_GetStreamSocketAddress(self.value)),
        };
    }

    /// Check if a stream socket is connected, without blocking.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to query.
    ///
    /// ## Return Value
    /// Returns `Status.success` if successfully connected, or `Status.waiting` if still connecting.
    ///
    /// ## Remarks
    /// The NET_StreamSocket objects returned by `StreamSocket.initClient` take time to do negotiate a connection to a server,
    /// so it does so asynchronously instead of making your program wait an indefinite amount of time.
    ///
    /// This function allows you to check the progress of that work without blocking.
    ///
    /// Connection can fail after some time (server took a while to respond, and then rejected the connection),
    /// so be sure to check the result of this function instead of assuming it worked because it's non-zero!
    ///
    /// Once a connection is successfully made, the stream socket can be used to send and receive data with the server.
    ///
    /// Note that if the connection succeeds, but later the connection is dropped, this will still report the connection as successful,
    /// as it only deals with the initial asynchronous work of getting connected; you'll know the connection dropped later when your reads and writes report failures.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getConnectionStatus(
        self: StreamSocket,
    ) !Status {
        return Status.fromSdl(c.NET_GetConnectionStatus(self.value));
    }

    /// Query bytes still pending transmission on a stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to query.
    ///
    /// ## Return Value
    /// Returns number of bytes still pending transmission.
    ///
    /// ## Remarks
    /// If `StreamSocket.write` couldn't send all its data immediately, it will queue it to be sent later.
    /// This function lets the app see how much of that queue is still pending to be sent.
    ///
    /// The library will try to send more queued data before reporting what's left, but it will not block to do so.
    ///
    /// If the connection has failed (remote side dropped us, or one of a million other networking failures occurred), this function will report failure.
    /// Stream sockets only report failure for unrecoverable conditions; once a stream socket fails,
    /// you should assume it is no longer usable and should destroy it with `StreamSocket.deinit`.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getPendingWrites(
        self: StreamSocket,
    ) !usize {
        const ret = c.NET_GetStreamSocketPendingWrites(self.value);
        return @intCast(try errors.wrapCall(c_int, ret, -1));
    }

    /// Begin connecting a socket as a client to a remote server.
    ///
    /// ## Function Parameters
    /// * `address`: The address of the remote server to connect to.
    /// * `port`: The port on the remote server to connect to.
    /// * `props`: Optional client properties.
    ///
    /// ## Return Value
    /// Returns a new `StreamSocket`, pending connection.
    ///
    /// ## Remarks
    /// Each `StreamSocket` represents a single connection between systems.
    /// Usually, a client app will have one connection to a server app on a different computer, and the server app might have many connections from different clients.
    /// Each of these connections communicate over a separate stream socket.
    ///
    /// Connecting is an asynchronous operation; this function does not block, and will return before the connection is complete.
    /// One has to then use `StreamSocket.waitUntilConnected` or `StreamSocket.getConnectionStatus` to see when the operation has completed, and if it was successful.
    ///
    /// Once connected, you can read and write data to the returned socket.
    /// Stream sockets are a mode of reliable transmission, which means data will be received as a stream of bytes in the order you sent it.
    /// If there are problems in transmission, the system will deal with protocol negotiation and retransmission as necessary,
    /// transparent to your app, but this means until data is available in the order sent, the remote side will not get any new data.
    /// This is the tradeoff vs datagram sockets, where data can arrive in any order, or not arrive at all, without waiting, but the sender will not know.
    ///
    /// Stream sockets don't employ any protocol (above the TCP level), so they can connect to servers that aren't using SDL net,
    /// but if you want to speak any protocol beyond an abritrary stream of bytes, such as HTTP, you'll have to implement that yourself on top of the stream socket.
    ///
    /// This function will fail if address is not finished resolving.
    ///
    /// When you are done with this connection (whether it failed to connect or not), you must dispose of it with `StreamSocket.deinit`.
    ///
    /// Unlike BSD sockets or WinSock, you specify the port as a normal integer; you do not have to byteswap it into "network order," as the library will handle that for you.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn initClient(
        address: Address,
        port: u16,
        props: ?InitProperties,
    ) !StreamSocket {
        _ = props;

        return .{
            .value = try errors.wrapCallNull(*c.NET_StreamSocket, c.NET_CreateClient(address.value, port, 0)),
        };
    }

    /// Receive bytes that a remote system sent to a stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to receive data from.
    /// * `buf`: A buffer where received data will be collected.
    ///
    /// ## Return Value
    /// Returns the bytes read from the stream socket.
    ///
    /// ## Remarks
    /// Stream sockets are reliable, which means data sent over them will arrive in the order it was transmitted, and the system will retransmit data as necessary to ensure its delivery.
    /// Which is to say, short of catastrophic failure, data will arrive, possibly with severe delays.
    /// Also, "catastrophic failure" isn't an uncommon event.
    ///
    /// This is opposed to Datagram sockets, which send chunks of data that might arrive in any order, or not arrive at all, but you never wait for missing chunks to show up.
    ///
    /// Stream sockets are bidirectional; you can read and write from the same stream, and the other end of the connection can, too.
    ///
    /// This function returns data that has arrived for the stream socket that hasn't been read yet.
    /// Data is provided in the order it was sent on the remote side.
    /// This function may return less data than requested, depending on what is available at the time, and also the app isn't required to read all available data at once.
    ///
    /// This call never blocks; if no new data is available at the time of the call, it returns no data immediately.
    /// The caller can try again later.
    ///
    /// If the connection has failed (remote side dropped us, or one of a million other networking failures occurred), this function will report failure.
    /// Stream sockets only report failure for unrecoverable conditions; once a stream socket fails,
    /// you should assume it is no longer usable and should destroy it with `StreamSocket.deinit`.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn read(
        self: StreamSocket,
        buf: []u8,
    ) ![]u8 {
        const ret = c.NET_ReadFromStreamSocket(self.value, buf.ptr, @intCast(buf.len));
        return buf[0..@intCast(try errors.wrapCall(c_int, ret, -1))];
    }

    /// Enable simulated stream socket failures.
    ///
    /// ## Function Parameters
    /// * `self`: The socket to set a failure rate on.
    /// * `percent_loss`: A number between `0` and `100`. Higher means more failures. Zero to disable.
    ///
    /// ## Remarks
    /// Often times, testing a networked app on your development machine--which might have a wired connection to a fast,
    /// reliable network service--won't expose bugs that happen when networks intermittently fail in the real world, when the wifi is flakey and firewalls get in the way.
    ///
    /// This function allows you to tell the library to pretend that some percentage of stream socket data transmission will fail.
    ///
    /// Since stream sockets are reliable, failure in this case pretends that packets are getting lost on the network, making the stream retransmit to deal with it.
    /// To simulate this, the library will introduce some amount of delay before it sends or receives data on the socket.
    /// The higher the percentage, the more delay is introduced for bytes to make their way to their final destination.
    /// The library may also decide to drop connections at random, to simulate disasterous network conditions.
    ///
    /// Setting this to zero (the default) will disable the simulation.
    /// Setting to `100` means everything fails unconditionally and no further data will get through (and perhaps your sockets eventually fail).
    /// At what percent the system merely borders on unusable is left as an exercise to the app developer.
    ///
    /// This is intended for debugging purposes, to simulate real-world conditions that are various degrees of terrible.
    /// You probably should not call this in production code, where you'll likely see real failures anyhow.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn simulatePacketLoss(
        self: StreamSocket,
        percent_loss: u7,
    ) void {
        std.debug.assert(percent_loss <= 100);
        c.NET_SimulateStreamPacketLoss(self.value, @intCast(percent_loss));
    }

    /// Block until a stream socket has connected to a server.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket object to wait on.
    /// * `timeout`: The maximum time to wait for connection to complete.
    ///
    /// ## Return Value
    /// Returns the connection status.
    ///
    /// ## Remarks
    /// The `StreamSocket` objects returned by `StreamSocket.initClient` take time to do their work,
    /// so it does so asynchronously instead of making your program wait an indefinite amount of time.
    ///
    /// However, if you want your program to sleep until the connection is complete, you can call this function.
    ///
    /// This function takes a timeout value, represented in milliseconds, of how long to wait for resolution to complete.
    ///
    /// Connections can fail after some time (server took awhile to respond at all, and then refused the connection outright),
    /// so be sure to check the result of this function instead of assuming it worked!
    ///
    /// Once a connection is successfully made, the socket may read data from, or write data to, the connected server.
    ///
    /// If you don't want your program to block, you can call `StreamSocket.getConnectionStatus` from time to time until you get a non-zero result.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different socket at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn waitUntilConnected(
        self: StreamSocket,
        timeout: Timeout,
    ) !Status {
        const ret = c.NET_WaitUntilConnected(self.value, timeout.toSdl());
        return Status.fromSdl(ret);
    }

    /// Block until all of a stream socket's pending data is sent.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to wait on.
    /// * `timeout`: The maximum time to wait for draining to complete.
    ///
    /// ## Return Value
    /// Returns number of bytes still pending transmission.
    ///
    /// ## Remarks
    /// If `StreamSocket.write` couldn't send all its data immediately, it will queue it to be sent later.
    /// This function lets the app sleep until all the data is transmitted.
    ///
    /// This function takes a timeout value, represented in milliseconds, of how long to wait for transmission to complete.
    ///
    /// If you don't want your program to block, you can call `StreamSocket.getPendingWrites` from time to time until you get a `result <= 0`.
    ///
    /// If the connection has failed (remote side dropped us, or one of a million other networking failures occurred), this function will report failure.
    /// Stream sockets only report failure for unrecoverable conditions; once a stream socket fails,
    /// you should assume it is no longer usable and should destroy it with StreamSocket.deinit`.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn waitUntilDrained(
        self: StreamSocket,
        timeout: Timeout,
    ) !usize {
        return @intCast(try errors.wrapCall(c_int, c.NET_WaitUntilStreamSocketDrained(self.value, timeout.toSdl()), -1));
    }

    /// Send bytes over a stream socket to a remote system.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to send data through.
    /// * `data`: the data to send.
    ///
    /// ## Remarks
    /// Stream sockets are reliable, which means data sent over them will arrive in the order it was transmitted,
    /// and the system will retransmit data as necessary to ensure its delivery.
    /// Which is to say, short of catastrophic failure, data will arrive, possibly with severe delays.
    /// Also, "catastrophic failure" isn't an uncommon event.
    ///
    /// This is opposed to `Datagram` sockets, which send chunks of data that might arrive in any order, or not arrive at all, but you never wait for missing chunks to show up.
    ///
    /// Stream sockets are bidirectional; you can read and write from the same stream, and the other end of the connection can, too.
    ///
    /// This call never blocks; if it can't send the data immediately, the library will queue it for later transmission.
    /// You can use `StreamSocket.getPendingWrites` to see how much is still queued for later transmission, or `StreamSocket.waitUntilDrained` to block until all pending data has been sent.
    ///
    /// If the connection has failed (remote side dropped us, or one of a million other networking failures occurred), this function will report failure.
    /// Stream sockets only report failure for unrecoverable conditions; once a stream socket fails,
    /// you should assume it is no longer usable and should destroy it with `StreamSocket.deinit`.
    ///
    /// Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn write(
        self: StreamSocket,
        data: []const u8,
    ) !void {
        return errors.wrapCallBool(c.NET_WriteToStreamSocket(self.value, data.ptr, @intCast(data.len)));
    }
};

/// SDL net version information.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub const Version = struct {
    value: c_int,

    /// SDL net version compiled against.
    ///
    /// ## Version
    /// This constant is available since SDL_net 3.0.0.
    pub const compiled_against = Version{ .value = c.SDL_NET_VERSION };

    /// Check if the SDL net version is at least greater than the given one.
    ///
    /// ## Function Parameters
    /// * `major`: The major version number.
    /// * `minor`: The minor version number.
    /// * `micro`: The micro version number.
    ///
    /// ## Return Value
    /// Returns if the net version is at least this given version.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn atLeast(
        major: u32,
        minor: u32,
        micro: u32,
    ) bool {
        const ret = c.SDL_NET_VERSION_ATLEAST(
            major,
            minor,
            micro,
        );
        return ret;
    }

    /// Create an SDL mixer version number.
    ///
    /// ## Function Parameters
    /// * `major`: The major version number.
    /// * `minor`: The minor version number.
    /// * `micro`: The micro version number.
    ///
    /// ## Return Value
    /// Returns the new version number.
    pub fn make(
        major: u32,
        minor: u32,
        micro: u32,
    ) Version {
        const ret = c.SDL_VERSIONNUM(
            @as(c_int, @intCast(major)),
            @as(c_int, @intCast(minor)),
            @as(c_int, @intCast(micro)),
        );
        return Version{ .value = ret };
    }

    /// This function gets the version of the dynamically linked SDL net library.
    ///
    /// ## Return Value
    /// Returns SDL net version.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn get() Version {
        const ret = c.NET_Version();
        return Version{ .value = ret };
    }

    /// Major version number.
    ///
    /// ## Function Parameters
    /// * `self`: The version.
    ///
    /// ## Return Value
    /// The major version number.
    pub fn getMajor(
        self: Version,
    ) u32 {
        const ret = c.SDL_VERSIONNUM_MAJOR(
            self.value,
        );
        return @intCast(ret);
    }

    /// Micro version number.
    ///
    /// ## Function Parameters
    /// * `self`: The version.
    ///
    /// ## Return Value
    /// The micro version number.
    pub fn getMicro(
        self: Version,
    ) u32 {
        const ret = c.SDL_VERSIONNUM_MICRO(
            self.value,
        );
        return @intCast(ret);
    }

    /// Minor version number.
    ///
    /// ## Function Parameters
    /// * `self`: The version.
    ///
    /// ## Return Value
    /// The minor version number.
    pub fn getMinor(
        self: Version,
    ) u32 {
        const ret = c.SDL_VERSIONNUM_MINOR(
            self.value,
        );
        return @intCast(ret);
    }
};

/// Specifies a timeout for a network operation.
///
/// ## Version
/// This type is provided by zig-sdl3.
pub const Timeout = union(enum) {
    /// Wait indefinitely.
    indefinite,
    /// Do not wait, check once and return immediately.
    no_wait,
    /// Wait for a specific number of milliseconds.
    milliseconds: usize,

    /// Convert to an SDL value.
    pub fn toSdl(self: Timeout) i32 {
        return switch (self) {
            .indefinite => -1,
            .no_wait => 0,
            .milliseconds => |ms| @intCast(ms),
        };
    }
};

/// Obtain a list of local addresses on the system.
///
/// ## Return Value
/// Returns a list of `Address` objects, one for each bindable address on the system.
/// The caller must call `LocalAddressList.deinit` on the returned list when done with it.
///
/// ## Remarks
/// This returns addresses that you can theoretically bind a socket to, to accept connections from other machines at that address.
///
/// You almost never need this function; first, it's hard to tell what is a good address to bind to, without asking the user (who will likely find it equally hard to decide).
/// Second, most machines will have lots of private addresses that are accessible on the same LAN, but not public ones that are accessible from the outside Internet.
///
/// Usually it's better to use `Server.init` or `DatagramSocket.init` with a `null` address, to say "bind to all interfaces".
///
/// Pass the returned array to `LocalAddressList.deinit` when you are done with it.
/// It is safe to keep any addresses you want from this array even after calling that function, as long as you called `Address.ref` on them.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn getLocalAddresses() !LocalAddressList {
    var num_addresses: c_int = undefined;
    const addresses: [*]Address = @ptrCast(@alignCast(try errors.wrapCallNull([*]?*c.NET_Address, c.NET_GetLocalAddresses(&num_addresses))));
    return .{
        .addresses = addresses[0..@intCast(num_addresses)],
    };
}

/// Initialize the SDL net library.
///
/// ## Remarks
/// This must be successfully called once before (almost) any other SDL net function can be used.
/// It is safe to call this multiple times; the library will only initialize once, and won't deinitialize until `quit` has been called a matching number of times.
/// Extra attempts to init report success.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn init() !void {
    return errors.wrapCallBool(c.NET_Init());
}

/// Deinitialize the SDL net library.
///
/// ## Remarks
/// This must be called when done with the library, probably at the end of your program.
///
/// It is safe to call this multiple times; the library will only deinitialize once, when this function is called the same number of times as `init` was successfully called.
///
/// Once you have successfully deinitialized the library, it is safe to call `init` to reinitialize it for further use.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn quit() void {
    c.NET_Quit();
}

/// Enable simulated address resolution failures.
///
/// ## Function Parameters
/// * `percent_loss`: A number between `0` and `100`. Higher means more failures. Zero to disable.
///
/// ## Remarks
/// Often times, testing a networked app on your development machine--which might have a wired connection to a fast,
/// reliable network service--won't expose bugs that happen when networks intermittently fail in the real world, when the wifi is flakey and firewalls get in the way.
///
/// This function allows you to tell the library to pretend that some percentage of address resolutions will fail.
///
/// The higher the percentage, the more resolutions will fail and/or take longer for resolution to complete.
///
/// Setting this to zero (the default) will disable the simulation.
/// Setting to `100` means everything fails unconditionally.
/// At what percent the system merely borders on unusable is left as an exercise to the app developer.
///
/// This is intended for debugging purposes, to simulate real-world conditions that are various degrees of terrible.
/// You probably should not call this in production code, where you'll likely see real failures anyhow.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn simulateAddressResolutionLoss(
    percent_loss: u7,
) void {
    std.debug.assert(percent_loss <= 100);
    c.NET_SimulateAddressResolutionLoss(@intCast(percent_loss));
}

/// Block on multiple sockets until at least one has data available.
///
/// ## Function Parameters
/// * `sockets`: An slice of `Pollable` sockets to wait on.
/// * `timeout`: The maximum time to wait for new input to become available.
///
/// ## Return Value
/// Returns the number of items that have new input.
///
/// ## Remarks
/// This is a complex function that most apps won't need, but it could be used to implement a more efficient server or I/O thread in some cases.
///
/// This allows you to give it a list of objects and wait for new input to become available on any of them. The calling thread is put to sleep until such a time.
///
/// This function takes a timeout value, represented in milliseconds, of how long to wait for resolution to complete.
///
/// This returns the number of items that have new input, but it does not tell you which ones; since access to them is non-blocking,
/// you can just try to read from each of them and see which are ready.
/// If nothing is ready and the timeout is reached, this returns zero.
///
/// ## Thread Safety
/// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
/// However, different threads may access different sockets at the same time without problems.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn waitUntilInputAvailable(
    sockets: []const Pollable,
    timeout: Timeout,
) !usize {
    const ret = c.NET_WaitUntilInputAvailable(@ptrCast(@alignCast(@constCast(sockets.ptr))), @intCast(sockets.len), timeout.toSdl());
    return @intCast(try errors.wrapCall(c_int, ret, -1));
}

test "net" {
    errors.refAllDeclsRecursive(@This());
}
