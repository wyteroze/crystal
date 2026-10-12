// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");

const Codec = @This();
type_name: []const u8,
size: u32,
read: *const fn (l: *zlua.Lua, idx: i32, out: []u8) void,
push: *const fn (l: *zlua.Lua, bytes: []const u8) void,

pub fn find(codecs: []const Codec, type_name: []const u8) ?*const Codec {
    for (codecs) |*c| if (std.mem.eql(u8, c.type_name, type_name)) return c;

    return null;
}