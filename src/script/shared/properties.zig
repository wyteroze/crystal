// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const log = @import("../../log.zig").lua;
const Lua = zlua.Lua;

pub fn Property(comptime T: type) type {
    return struct {
        name: []const u8,
        get: ?*const fn (l: *Lua, self: *T) i32 = null,
        set: ?*const fn (l: *Lua, self: *T) void = null
    };
}

pub fn dispatchIndex(comptime T: type, comptime props: []const Property(T), l: *Lua, self: *T, key: []const u8) ?i32 {
    inline for (props) |prop| {
        if (std.mem.eql(u8, key, prop.name)) {
            if (prop.get) |g| { return g(l, self); }

            l.raiseErrorStr("'%s' is write-only, you may not read from it", .{ key.ptr });
            return 0;
        }
    }

    return null;
}

pub fn dispatchNewIndex(comptime T: type, comptime props: []const Property(T), l: *Lua, self: *T, key: []const u8) ?void {
    inline for (props) |prop| {
        if (std.mem.eql(u8, key, prop.name)) {
            if (prop.set) |s| { s(l, self); return; }

            l.raiseError("'%s' is read-only, you may not assign to it", .{ key.ptr });
            return 0;
        }
    }

    return null;
}
