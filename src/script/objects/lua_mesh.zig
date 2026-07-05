// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const types = @import("../../types.zig");
const Lua = zlua.Lua;
const object = @import("../../object.zig");

const Mesh = @import("../../Mesh.zig").Mesh;
const Sprite = @import("../../Sprite.zig").Sprite;

pub fn index(_: *Lua, _: *object.MeshObject, _: []const u8) ?i32 { return null; }

pub fn newIndex(_: *Lua, _: *object.MeshObject, _: []const u8) ?void { return null; }

pub fn gc(l: *Lua, m: *object.MeshObject, _: std.mem.Allocator) void {
    l.unref(zlua.registry_index, m.mesh_ref);
    if (m.texture_ref) |r| l.unref(zlua.registry_index, r);
}

pub fn construct(l: *Lua, obj: *object.Object, _: std.mem.Allocator) i32 {
    const mesh_data = l.checkUserdata(Mesh, 1, "MeshData");
    l.pushValue(1);
    const mesh_ref = l.ref(zlua.registry_index);

    var texture_ref: ?i32 = null;
    const texture = if (l.isNoneOrNil(2)) null else blk: {
        const t = l.checkUserdata(Sprite, 2, "ImageData");
        l.pushValue(2);
        texture_ref = l.ref(zlua.registry_index);
        break :blk t;
    };

    obj.* = .{
        .transform = types.Transform.identity(),
        .data = .{ .mesh = .{ .mesh = mesh_data, .texture = texture, .mesh_ref = mesh_ref, .texture_ref = texture_ref } }
    };

    return 1;
}
