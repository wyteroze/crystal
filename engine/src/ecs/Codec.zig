// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const ecs = @import("ecs.zig");

pub const ReadFn = *const fn (l: *zlua.Lua, idx: i32, out: []u8) void;
pub const PushFn = *const fn (l: *zlua.Lua, bytes: []const u8) void;
pub const PushComponentFn = *const fn (l: *zlua.Lua, e: ecs.Entity, bytes: []const u8) void;

const Codec = @This();
type_name: []const u8,
size: u32,
read: ReadFn,
push: PushFn,
push_component: ?PushComponentFn = null,

pub fn find(codecs: []const Codec, type_name: []const u8) ?*const Codec {
    for (codecs) |*c| if (std.mem.eql(u8, c.type_name, type_name)) return c;

    return null;
}