// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const types = @import("../../types.zig");
const shared = @import("../shared.zig");
const strEq = shared.strEq;
const Lua = zlua.Lua;
const object = @import("../../object.zig");

const Sprite = @import("../../Sprite.zig").Sprite;

pub fn index(_: *Lua, _: *object.ImageObject, _: []const u8) ?i32 { return null; }

pub fn newIndex(_: *Lua, _: *object.ImageObject, _: []const u8) ?void { return null; }

pub fn gc(l: *Lua, i: *object.ImageObject, _: std.mem.Allocator) void {
    l.unref(zlua.registry_index, i.image_ref);
}

pub fn construct(l: *Lua, obj: *object.Object, _: std.mem.Allocator) i32 {
    const image_data = l.checkUserdata(Sprite, 1, "ImageData");
    l.pushValue(1);

    const image_ref = l.ref(zlua.registry_index);
    obj.* = .{
        .transform = types.Transform.identity(),
        .data = .{ .image = .{ .image = image_data, .image_ref = image_ref } }
    };

    return 1;
}
