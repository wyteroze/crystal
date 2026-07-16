// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");

pub fn Tagged(comptime scope: @EnumLiteral(), comptime tag: []const u8) type {
    const base = std.log.scoped(scope);

    return struct {
        pub fn debug(comptime fmt: []const u8, args: anytype) void { base.debug("[" ++ tag ++ "] " ++ fmt, args); }
        pub fn info(comptime fmt: []const u8, args: anytype) void { base.info("[" ++ tag ++ "] " ++ fmt, args); }
        pub fn warn(comptime fmt: []const u8, args: anytype) void { base.warn("[" ++ tag ++ "] " ++ fmt, args); }
        pub fn err(comptime fmt: []const u8, args: anytype) void { base.err("[" ++ tag ++ "] " ++ fmt, args); }
    };
}

// ScriptEngine
pub const script    = std.log.scoped(.script);
pub const lua       = Tagged(.script, "lua");

// Render
pub const render    = std.log.scoped(.render);

// Parse
pub const parse     = std.log.scoped(.parse);
pub const obj       = Tagged(.parse, "obj");
pub const bmp       = Tagged(.parse, "bmp");
pub const wav       = Tagged(.parse, "wav");
pub const toml      = Tagged(.parse, "toml");

// Engine
pub const engine    = std.log.scoped(.engine);
pub const config    = Tagged(.engine, "config");
