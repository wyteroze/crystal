// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const log = @import("../log.zig").lua;
const types = @import("../types.zig");
const shared = @import("shared.zig");
const Object = @import("../object.zig").Object;
const Mesh = @import("../Mesh.zig").Mesh;
const Sprite = @import("../Sprite.zig").Sprite;
const Camera = @import("../Camera.zig").Camera;
const Lua = zlua.Lua;

const lua_vec = @import("lua_vec.zig");
const lua_camera = @import("objects/lua_camera.zig");
const lua_image = @import("objects/lua_image.zig");
const lua_mesh = @import("objects/lua_mesh.zig");

var allocator: std.mem.Allocator = undefined;

const scene_object_methods = [_]zlua.FnReg{};

const object_lib = [_]zlua.FnReg{
    .{ .name = "mesh", .func = zlua.wrap(objectMesh) },
    .{ .name = "image", .func = zlua.wrap(objectImage) },
    .{ .name = "camera", .func = zlua.wrap(objectCamera) }
};

fn objectIndex(l: *Lua) i32 {
    const obj = l.checkUserdata(Object, 1, "Object");
    const key = l.checkString(2);
    if (std.mem.eql(u8, key, "Position")) { lua_vec.pushVec3Ref(l, &obj.transform.position); return 1; }
    if (std.mem.eql(u8, key, "Rotation")) { lua_vec.pushVec3Ref(l, &obj.transform.rotation); return 1; }
    if (std.mem.eql(u8, key, "Scale"))    { lua_vec.pushVec3Ref(l, &obj.transform.scale);    return 1; }

    const result = switch (obj.data) {
        .camera => |*c| lua_camera.index(l, c, key),
        .mesh => |*m| lua_mesh.index(l, m, key),
        .image => |*i| lua_image.index(l, i, key),
    };
    if (result) |r| return r;

    l.raiseErrorStr("no property named '%s' exists", .{ key.ptr });
    return 0;
}

fn objectNewIndex(l: *Lua) i32 {
    const obj = l.checkUserdata(Object, 1, "Object");
    const key = l.checkString(2);
    if (std.mem.eql(u8, key, "Position")) { obj.transform.position = lua_vec.checkVec3(l, 3); return 0; }
    if (std.mem.eql(u8, key, "Rotation")) { obj.transform.rotation = lua_vec.checkVec3(l, 3); return 0; }
    if (std.mem.eql(u8, key, "Scale"))    { obj.transform.scale    = lua_vec.checkVec3(l, 3); return 0; }

    const handled = switch (obj.data) {
        .camera => |*c| lua_camera.newIndex(l, c, key),
        .mesh => |*m| lua_mesh.newIndex(l, m, key),
        .image => |*i| lua_image.newIndex(l, i, key),
    };
    if (handled != null) return 0;

    l.raiseErrorStr("no property named '%s' exists, you can not assign to it", .{ key.ptr });
    return 0;
}

fn objectMesh(l: *Lua) i32 {
    const obj = l.newUserdata(Object, 0);
    const r = lua_mesh.construct(l, obj, allocator);
    if (r == 1) shared.setObjectMetatable(l);

    return 1;
}

fn objectImage(l: *Lua) i32 {
    const obj = l.newUserdata(Object, 0);
    const r = lua_image.construct(l, obj, allocator);
    if (r == 1) shared.setObjectMetatable(l);

    return 1;
}

fn objectCamera(l: *Lua) i32 {
    const obj = l.newUserdata(Object, 0);
    const r = lua_camera.construct(l, obj, allocator);
    if (r == 1) shared.setObjectMetatable(l);

    return 1;
}

pub fn objectGc(l: *Lua) i32 {
    const obj = l.checkUserdata(Object, 1, "Object");
    switch (obj.data) {
        .mesh => |*m| lua_mesh.gc(l, m, allocator),
        .image => |*i| lua_image.gc(l, i, allocator),
        .camera => |*c| lua_camera.gc(l, c, allocator),
    }

    return 0;
}

pub fn register(l: *Lua, a: std.mem.Allocator) !void {
    allocator = a;

    // Object object
    try l.newMetatable("Object");
    l.pushFunction(zlua.wrap(objectIndex));
    l.setField(-2, "__index");
    l.pushFunction(zlua.wrap(objectNewIndex));
    l.setField(-2, "__newindex");
    l.pushFunction(zlua.wrap(objectGc));
    l.setField(-2, "__gc");

    // for any shared methods in the future, we don't have any
    l.setFuncs(&scene_object_methods, 0);
    l.pop(1);

    // Object library
    l.newTable();
    l.setFuncs(&object_lib, 0);
    l.setGlobal("Object");
}
