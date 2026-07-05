// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const log = @import("../../log.zig").lua;
const Lua = zlua.Lua;

pub const LuaRef = struct {
    ref: i32,

    pub fn capture(l: *Lua, idx: i32) LuaRef {
        l.pushValue(idx);
        return .{
            .ref = l.ref(zlua.registry_index)
        };
    }

    pub fn push(self: *LuaRef, l: *Lua) void {
        _ = l.getIndexRaw(zlua.registry_index, self.ref);
    }

    pub fn release(self: LuaRef, l: *Lua) void {
        l.unref(zlua.registry_index, self.ref);
    }
};

pub fn LuaRefMap(comptime K: type) type {
    return struct {
        map: std.AutoHashMap(K, LuaRef),

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{ .map = std.AutoHashMap(K, LuaRef).init(allocator) };
        }

        pub fn track(self: *@This(), l: *Lua, key: K, idx: i32) !void {
            try self.map.put(key, LuaRef.capture(l, idx));
        }

        pub fn untrack(self: *@This(), l: *Lua, key: K) void {
            if (self.map.fetchRemove(key)) |e| e.value.release(l);
        }

        pub fn deinit(self: *@This(), l: *Lua) void {
            var it = self.map.iterator();
            while (it.next()) |e|
                e.value_ptr.release(l);

            self.map.deinit();
        }
    };
}
