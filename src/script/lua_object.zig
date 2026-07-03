// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const log = @import("../log.zig").lua;
const types = @import("../types.zig");
const shared = @import("shared.zig");
const lua_vec = @import("lua_vec.zig");
const Object = @import("../Object.zig").Object;
const Mesh = @import("../Mesh.zig").Mesh;
const Sprite = @import("../Sprite.zig").Sprite;
const Lua = zlua.Lua;

const scene_object_methods = [_]zlua.FnReg{};
const object_lib = [_]zlua.FnReg{
    .{ .name = "mesh", .func = zlua.wrap(objectMesh) },
    .{ .name = "image", .func = zlua.wrap(objectImage) }
};

fn objectIndex(l: *Lua) i32 {
    const obj = l.checkUserdata(Object, 1, "Object");
    const key = l.checkString(2);
    if (std.mem.eql(u8, key, "Position")) { lua_vec.pushVec3(l, obj.transform.position); return 1; }
    if (std.mem.eql(u8, key, "Rotation")) { lua_vec.pushVec3(l, obj.transform.rotation); return 1; }
    if (std.mem.eql(u8, key, "Scale"))    { lua_vec.pushVec3(l, obj.transform.scale);    return 1; }

    l.raiseErrorStr("no property named '%s' exists", .{ key.ptr });
    return 0;
}

fn objectNewIndex(l: *Lua) i32 {
    const obj = l.checkUserdata(Object, 1, "Object");
    const key = l.checkString(2);
    if (std.mem.eql(u8, key, "Position")) { obj.transform.position = lua_vec.checkVec3(l, 3); return 0; }
    if (std.mem.eql(u8, key, "Rotation")) { obj.transform.rotation = lua_vec.checkVec3(l, 3); return 0; }
    if (std.mem.eql(u8, key, "Scale"))    { obj.transform.scale    = lua_vec.checkVec3(l, 3); return 0; }

    l.raiseErrorStr("no property named '%s' exists, you can not assign to it", .{ key.ptr });
    return 0;
}

fn objectMesh(l: *Lua) i32 {
    const mesh_data = l.checkUserdata(Mesh, 1, "MeshData");
    const texture = if (l.isNoneOrNil(2)) null else l.checkUserdata(Sprite, 2, "ImageData");
    const obj = l.newUserdata(Object, 0);
    obj.* = .{
        .transform = types.Transform.identity(),
        .data = .{ .mesh = .{ .mesh = mesh_data, .texture = texture } }
    };

    shared.setObjectMetatable(l);
    return 1;
}

fn objectImage(l: *Lua) i32 {
    const image_data = l.checkUserdata(Sprite, 1, "ImageData");
    const obj = l.newUserdata(Object, 0);
    obj.* = .{
        .transform = types.Transform.identity(),
        .data = .{ .image = .{ .image = image_data } }
    };

    shared.setObjectMetatable(l);
    return 1;
}

pub fn register(l: *Lua) !void {
    // Object object
    try l.newMetatable("Object");
    l.pushFunction(zlua.wrap(objectIndex));
    l.setField(-2, "__index");
    l.pushFunction(zlua.wrap(objectNewIndex));
    l.setField(-2, "__newindex");
    // for any shared methods in the future, we don't have any
    l.setFuncs(&scene_object_methods, 0);
    l.pop(1);

    // Object library
    l.newTable();
    l.setFuncs(&object_lib, 0);
    l.setGlobal("Object");
}
