// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;

const lua_vec = @import("lua_vec.zig");

pub const ScriptEngine = struct {
    lua: *Lua,

    pub fn init(allocator: std.mem.Allocator) !ScriptEngine {
        var lua = try Lua.init(allocator);
        try lua_vec.register(lua);

        lua.openLibs();

        return .{
            .lua = lua
        };
    }

    // Runs a script from the given path. Handles all errors
    pub fn runFile(self: *ScriptEngine, file: [:0]const u8) void {
        self.lua.doFile(file) catch {
            const msg = self.lua.toString(-1) catch "unknown error";
            std.debug.print("{s}", .{ msg.ptr });
        };
    }

    pub fn deinit(self: *ScriptEngine) void {
        self.lua.deinit();
    }
};
