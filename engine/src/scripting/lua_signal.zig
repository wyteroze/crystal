// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const bind = @import("bind/bind.zig");
const Host = @import("bind/Host.zig");
const Codec = @import("../ecs/Codec.zig");
const signal = @import("../core/signal.zig");

const LuaCallback = struct {
    l: *zlua.Lua,
    ref: i32
};

pub fn Handle(comptime S: type) type {
    return struct { signal: *S };
}

pub const connection = bind.value(signal.Connection, .{
    .name = "Connection",
    .methods = &.{
        bind.func("Disconnect", signal.Connection.disconnect)
    },
});

pub fn handle(comptime S: type) @TypeOf(bind.handle(Handle(S), .{})) {
    return bind.handle(Handle(S), .{
        .name = "Signal",
        .methods = &.{
            bind.func("Connect", connectFn(S))
        },
        .ops = .{}
    });
}

fn freeCallback(allocator: std.mem.Allocator, ctx: *anyopaque) void {
    const cb: *LuaCallback = @ptrCast(@alignCast(ctx));
    cb.l.unref(cb.ref);
    allocator.destroy(cb);
}

fn pushArg(l: *zlua.Lua, codecs: []const Codec, a: anytype) void {
    const T = @TypeOf(a);
    switch (@typeInfo(T)) {
        .bool => l.pushBoolean(a),
        .int => l.pushInteger(@intCast(a)),
        .float => l.pushNumber(@floatCast(a)),
        else => {
            const c = Codec.find(codecs, @typeName(T)) orelse {
                std.log.err("Signal arg {s} is not bound to Lua", .{ @typeName(T) });
                l.pushNil();
                return;
            };
            c.push(l, std.mem.asBytes(&a));
        }
    }
}

fn trampoline(comptime S: type) fn (*LuaCallback, S.Args) void {
    return struct {
        fn f(cb: *LuaCallback, args: S.Args) void {
            // The callback might free itself, so we copy this out.
            const l = cb.l;
            const codecs = Host.fromState(l).codecs;

            _ = l.getIndexRaw(zlua.registry_index, cb.ref);
            inline for (args) |a| pushArg(l, codecs, a);

            l.protectedCall(.{ .args = args.len, .results = 0 }) catch {
                const msg = l.toString(-1) catch "unknown error";
                std.log.err("Signal callback failed: {s}", .{ msg });
                l.pop(1);
            };
        }
    }.f;
}

fn connectFn(comptime S: type) fn (Handle(S), *zlua.Lua) anyerror!signal.Connection {
    return struct {
        fn f(h: Handle(S), l: *zlua.Lua) anyerror!signal.Connection {
            if (!l.isFunction(2)) l.typeError(2, "function");

            const allocator = h.signal.allocator;
            const cb = try allocator.create(LuaCallback);
            errdefer allocator.destroy(cb);

            cb.* = .{ .l = l.mainThread(), .ref = l.ref(2) };
            return h.signal.rawConnect(trampoline(S), cb, freeCallback) catch |e| {
                freeCallback(allocator, cb);
                return e;
            };
        }
    }.f;
}