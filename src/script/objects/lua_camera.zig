// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const types = @import("../../types.zig");
const Lua = zlua.Lua;
const object = @import("../../object.zig");

const Camera = @import("../../Camera.zig").Camera;
const lua_vec = @import("../lua_vec.zig");

pub fn index(l: *Lua, c: *object.CameraObject, key: []const u8) ?i32 {
    if (std.mem.eql(u8, key, "Fov"))           { l.pushNumber(c.camera.fov); return 1; }
    if (std.mem.eql(u8, key, "UpVector"))      { lua_vec.pushVec3(l, c.camera.getUpDirection()); return 1; }
    if (std.mem.eql(u8, key, "RightVector"))   { lua_vec.pushVec3(l, c.camera.getRightDirection()); return 1; }
    if (std.mem.eql(u8, key, "ForwardVector")) { lua_vec.pushVec3(l, c.camera.getLookDirection()); return 1; }

    return null;
}

pub fn newIndex(l: *Lua, _: *object.CameraObject, key: []const u8) ?void {
    if (std.mem.eql(u8, key, "ForwardVector") or std.mem.eql(u8, key, "Far") or std.mem.eql(u8, key, "Near") or std.mem.eql(u8, key, "Fov")) {
        l.raiseErrorStr("'%s' is read-only, you may not assign to it", .{ key.ptr });
        return 0;
    }

    return null;
}

pub fn gc(_: *Lua, c: *object.CameraObject, allocator: std.mem.Allocator) void {
    allocator.destroy(c.camera);
}

pub fn construct(l: *Lua, obj: *object.Object, allocator: std.mem.Allocator) i32 {
    const native_camera = allocator.create(Camera) catch {
        l.raiseErrorStr("out of memory creating camera", .{});
        return 0;
    };

    native_camera.* = Camera.init(0.1, 1000.0, 90.0, undefined);
    obj.* = .{
        .transform = types.Transform.identity(),
        .data = .{ .camera = .{ .camera = native_camera } }
    };
    native_camera.transform = &obj.transform;

    return 1;
}
