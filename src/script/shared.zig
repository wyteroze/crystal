// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const marshal = @import("reflect/marshal.zig");
const log = @import("../log.zig").script;
const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;

pub const Diagnostic = struct {
    buf: [256]u8 = undefined,
    message: []const u8 = "",

    /// This function uses zig formatting specifiers, not lua. (ex. `{s}` instead of `%s`)
    pub fn set(self: *Diagnostic, comptime fmt: []const u8, args: anytype) void {
        self.message = std.fmt.bufPrint(&self.buf, fmt, args) catch fmt;
    }
};

// floating point is funky
pub inline fn cleanFloatingPoint(num: f64) f64 {
    return (if (@abs(num) < 1e-6) 0 else num);
}

pub const Callback = struct {
    pub const LuaCallback = true; // just so marshal knows this is a callback
    lua: *Lua,
    ref: i32,

    pub fn call(self: Callback, args: anytype) void {
        _ = self.lua.getIndexRaw(zlua.registry_index, self.ref);
        inline for (args) |a| marshal.push(self.lua, a);

        self.lua.protectedCall(.{ .args = args.len, .results = 0 }) catch {
            log.err("callback error: {s}", .{ self.lua.toString(-1) catch "???" });
            self.lua.pop(1);
        };
    }

    pub fn deinit(self: Callback) void {
        self.lua.unref(zlua.registry_index, self.ref);
    }
};
