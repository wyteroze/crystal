// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const module = @import("module.zig");
const class = @import("class.zig");
pub const marshal = @import("marshal.zig");
const Lua = zlua.Lua;

pub fn registerAllLibs(l: *Lua, comptime libs: type, ctx: anytype) !void {
    inline for (comptime std.meta.declarations(libs)) |d| {
        const lib_name = d.name;
        const Lib = @field(libs, lib_name);

        var instance = try module.callInitWithMatchingArgs(Lib, ctx);
        try module.registerModule(l, Lib, &instance, lib_name);
    }
}

pub fn registerAllObjects(l: *Lua, comptime objects: type) !void {
    inline for (comptime std.meta.declarations(objects)) |d| {
        const object_name = d.name;
        const Object = @field(objects, object_name);

        try class.registerClass(l, Object, object_name);
    }
}
