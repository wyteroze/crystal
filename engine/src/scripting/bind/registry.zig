// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const types = @import("types.zig");
const signal = @import("signal.zig");
const Marshal = @import("marshal.zig").Marshal;

pub const Entry = struct { T: type, member: types.Member };
pub fn Registry(comptime api: anytype) type {
    return struct {
        pub const entries: []const Entry = collectEntries(api, @This());
        comptime { if (entries.len > 127) @compileError("Userdata tag limit reached"); }

        pub fn tagOf(comptime T: type) u8 {
            inline for (entries, 0..) |e, i| if (e.T == T) return i;
            @compileError(std.fmt.comptimePrint("{s} is not registered!", .{ @typeName(T) }));
        }

        pub fn kindOf(comptime T: type) ?types.Kind {
            inline for (entries) |e| if (e.T == T) return e.member.kind;
            return null;
        }
    };
}

fn addUnique(comptime list: []const type, comptime T: type) []const type {
    for (list) |x| if (x == T) return list;
    return list ++ .{ T };
}


fn collectEntries(comptime api: anytype, comptime Reg: type) []const Entry { comptime {
    var out: []const Entry = &.{};
    for (api) |mod| for (mod.impl.recipe.members) |m| switch (m.kind) {
        .value, .handle, .object => out = out ++ .{ Entry{ .T = m.impl.Type, .member = m } },
        else => {}
    };

    for (out, 0..) |a, i| for (out[i+1..]) |b| {
        if (a.T == b.T) @compileError(std.fmt.comptimePrint("Type bound twice: {s}", .{ @typeName(a.T) }));
    };  

    // These are generated, not user-declared
    var sigs: []const type = &.{};
    for (api) |mod| for (mod.impl.recipe.members) |m| switch (m.kind) {
        .signal => sigs = addUnique(sigs, m.impl.Signal),
        .value, .handle, .object => for (m.impl.recipe.signals) |s| {
            sigs = addUnique(sigs, s.impl.Signal);
        },

        else => {}
    };

    for (sigs) |Sig| out = out ++ .{ Entry{ .T = signal.Handle(Sig), .member = signal.handle(Sig, Marshal(Reg)) } };
    out = out ++ .{ Entry{ .T = signal.connection.impl.Type, .member = signal.connection } };
    
    return out;
} }
