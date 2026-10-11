// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const Codec = @import("Codec.zig");
const ComponentId = @import("ComponentId.zig");

const ComponentInfo = @This();

name: []const u8,
size: u32,
alignment: u32,
codec: ?Codec,
fields: []Codec.FieldDesc = &.{},

pub fn read(self: *const ComponentInfo, a: std.mem.Allocator, lua: *zlua.Lua, idx: i32, out: []u8) anyerror!void {
    if (self.codec) |c| return c.read(a, lua, idx, out);

    const abs = lua.absIndex(idx);
    if (lua.typeOf(abs) != .table) return error.ExpectedTable;
    var done: usize = 0;

    errdefer for (self.fields[0..done]) |f| {
        if (f.codec.free) |fr| fr(a, out[f.offset..][0..f.codec.size]);
    };

    for (self.fields) |f| {
        _ = lua.pushString(f.name);
        _ = lua.getTable(abs);
        defer lua.pop(1);

        try f.codec.read(a, lua, -1, out[f.offset..][0..f.codec.size]);
        done += 1;
    }
}

pub fn write(self: *const ComponentInfo, lua: *zlua.Lua, bytes: []const u8) void {
    if (self.codec) |c| return c.write(lua, bytes);

    lua.createTable(0, @intCast(self.fields.len));
    for (self.fields) |f| {
        _ = lua.pushString(f.name);
        f.codec.write(lua, bytes[f.offset..][0..f.codec.size]);
        lua.setTable(-3);
    }
}

pub fn free(self: *const ComponentInfo, a: std.mem.Allocator, bytes: []u8) void {
    if (self.codec) |c| {
        if (c.free) |fr| fr(a, bytes);
        return;
    }

    for (self.fields) |f| {
        if (f.codec.free) |fr| fr(a, bytes[f.offset..][0..f.codec.size]);
    }
}

pub fn fieldList(self: *const ComponentInfo) []const Codec.FieldDesc {
    return if (self.codec) |c| c.fields else self.fields;
}

pub fn isProxy(self: *const ComponentInfo) bool {
    return self.fieldList().len > 0;
}

pub fn field(self: *const ComponentInfo, name: []const u8) ?Codec.FieldDesc {
    for (self.fieldList()) |f| if (std.mem.eql(u8, f.name, name)) return f;
    return null;
}