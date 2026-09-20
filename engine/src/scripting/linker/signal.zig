// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const util = @import("util.zig");
const recipes = @import("recipes.zig");
const Binding = @import("Binding.zig").Binding;
const signal_lib = @import("../../core/signal.zig");
const linker = @import("linker.zig");
const Lua = zlua.Lua;

const LuaSignalCtx = struct {
    lua: *Lua,
    ref: i32
};

pub fn signal(l: *Lua, comptime SignalType: type) void {
    linker.reference(l, SignalType, .{
        .name = .auto,
        .scope = .{ .module = "core.signal" },
        .methods = &.{
            .custom("Connect", luaConnect(SignalType)),
            .named("Fire", SignalType.fire)
        }
    });

    linker.value(l, SignalType.Connection, .{
        .name = .auto,
        .scope = .{ .module = "core.signal" },
        .methods = &.{
            .custom("Disconnect", luaDisconnect(SignalType))
        }
    });
}

fn luaConnect(comptime SignalType: type) fn (l: *Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const self = Binding(SignalType, true).check(l, 1);

            l.pushValue(2);
            const ref = l.ref(zlua.registry_index);
            const ctx = self.arena.allocator().create(LuaSignalCtx) catch |e| util.luaErr(l, e, .{});
            ctx.* = .{ .lua = l, .ref = ref };

            const con = self.rawConnect(struct {
                fn c(sig_ctx: *LuaSignalCtx, args: SignalType.Args) void {
                    _ = sig_ctx.lua.getIndexRaw(zlua.registry_index, sig_ctx.ref);
                    inline for (args) |a| util.pushVal(sig_ctx.lua, @TypeOf(a), a);
                    sig_ctx.lua.protectedCall(.{ .args = args.len, .results = 0 }) catch |e| util.luaErr(sig_ctx.lua, e, .{});
                }
            }.c, ctx) catch |e| util.luaErr(l, e, .{});

            util.pushVal(l, SignalType.Connection, con);
            return 1;
        }
    }.c;
}

fn luaDisconnect(comptime SignalType: type) fn (l: *Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const con = Binding(SignalType.Connection, false).check(l, 1);

            if (con.signal.callbacks.get(con.id)) |cb| {
                const ctx: *LuaSignalCtx = @ptrCast(@alignCast(cb.ctx));
                ctx.lua.unref(zlua.registry_index, ctx.ref);
                con.signal.arena.allocator().destroy(ctx);
            }

            con.disconnect();
            return 0;
        }
    }.c;
}