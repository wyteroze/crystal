// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const types = @import("types.zig");

pub const Entry = struct { T: type, member: types.Member };
pub fn Registry(comptime api: anytype) type {
    return struct {
        pub const entries: []const Entry = collectEntries(api);
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

fn collectEntries(comptime api: anytype) []const Entry { comptime {
    var out: []const Entry = &.{};
    for (api) |mod| for (mod.impl.recipe.members) |m| switch(m.kind) {
        .value, .handle, .object => out = out ++ &[_]Entry{ .{ .T = m.impl.Type, .member = m } },
        else => {}
    };

    for (out, 0..) |a, i| for (out[i+1..]) |b| {
        if (a.T == b.T) @compileError(std.fmt.comptimePrint("Type bound twice: {s}", .{ @typeName(a.T) }));
    };
    
    return out;
} }