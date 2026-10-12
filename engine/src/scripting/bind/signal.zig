// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const bind = @import("bind.zig");
const types = @import("types.zig");
const signal = @import("../../core/signal.zig");

const LuaCallback = struct {
    l: *zlua.Lua,
    ref: i32,
};

pub fn Handle(comptime Sig: type) type {
    return struct { signal: *Sig };
}

pub const connection = bind.value(signal.Connection, .{
    .name = "SignalConnection",
    .methods = &.{
        bind.func("Disconnect", signal.Connection.disconnect)
    }
});

pub fn handle(comptime Sig: type, comptime Mar: type) types.Member {
    return bind.handle(Handle(Sig), .{
        .name = "Signal",
        .methods = &.{
            bind.func("Connect", connectFn(Sig, Mar))
        },
    });
}

fn freeCallback(allocator: std.mem.Allocator, ctx: *anyopaque) void {
    const cb: *LuaCallback = @ptrCast(@alignCast(ctx));
    cb.l.unref(cb.ref);

    allocator.destroy(cb);
}

fn callbackWrapper(comptime S: type, comptime Mar: type) fn (*LuaCallback, S.Args) void {
    return struct {
        fn f(cb: *LuaCallback, args: S.Args) void {
            // The callback might free itself, so we copy this out.
            const l = cb.l;

            _ = l.getIndexRaw(zlua.registry_index, cb.ref);
            inline for (args) |a| Mar.push(l, a);

            l.protectedCall(.{ .args = args.len, .results = 0 }) catch {
                const msg = l.toString(-1) catch "unknown error";
                std.log.err("Signal callback failed: {s}", .{ msg });
                l.pop(1);
            };
        }
    }.f;
}

fn connectFn(comptime Sig: type, comptime Mar: type) fn (Handle(Sig), *zlua.Lua) anyerror!signal.Connection {
    return struct {
        fn f(h: Handle(Sig), l: *zlua.Lua) anyerror!signal.Connection {
            if (!l.isFunction(2)) l.typeError(2, "function");

            const allocator = h.signal.allocator;
            const cb = try allocator.create(LuaCallback);
            errdefer allocator.destroy(cb);

            cb.* = .{ .l = l.mainThread(), .ref = l.ref(2) };
            return h.signal.rawConnect(callbackWrapper(Sig, Mar), cb, freeCallback) catch |e| {
                freeCallback(allocator, cb);
                return e;
            };
        }
    }.f;
}