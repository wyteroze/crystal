// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const log = @import("../log.zig").lua;
const Scene = @import("../Scene.zig").Scene;
const Object = @import("../Object.zig").Object;
const Lua = zlua.Lua;
var allocator: std.mem.Allocator = undefined;

const UpdateHandler = struct {
    lua: *Lua,
    ref: i32,
    disconnected: bool = false,

    fn call(ctx: ?*anyopaque, dt: f32) void {
        const self = @as(*UpdateHandler, @ptrCast(@alignCast(ctx.?)));
        if (self.disconnected) return;
        const l = self.lua;

        _ = l.getIndexRaw(zlua.registry_index, self.ref);
        l.pushNumber(dt);
        l.protectedCall(.{ .args = 1, .results = 0 }) catch {
            log.err("OnUpdate callback error: {s}", .{ l.toString(-1) catch "???" });
            l.pop(1);
        };
    }
};

const scene_lib = [_]zlua.FnReg{
    .{ .name = "new", .func = zlua.wrap(sceneNew) }
};

const scene_methods = [_]zlua.FnReg{
    .{ .name = "OnUpdate", .func = zlua.wrap(sceneOnUpdate) },
    .{ .name = "AddObject", .func = zlua.wrap(sceneAddObject) },
    .{ .name = "RemoveObject", .func = zlua.wrap(sceneRemoveObject) }
};

pub fn sceneNew(l: *Lua) i32 {
    const name = l.optString(1);
    const scene = l.newUserdata(Scene, 0);
    scene.* = Scene.init(allocator, name);

    l.setMetatableRegistry("Scene");
    return 1;
}

pub fn sceneOnUpdate(l: *Lua) i32 {
    const self = l.checkUserdata(Scene, 1, "Scene");

    l.checkType(2, .function);
    l.pushValue(2);
    const callback_ref = l.ref(zlua.registry_index);

    const handler = allocator.create(UpdateHandler) catch {
        l.raiseErrorStr("out of memory registering OnUpdate callback", .{});
        return 0;
    };

    handler.* = .{ .lua = l, .ref = callback_ref };
    self.addUpdateCallback(.{ .ctx = handler, .func = UpdateHandler.call }) catch {
        l.raiseErrorStr("out of memory registering OnUpdate callback", .{});
        return 0;
    };

    l.pushValue(1);
    l.pushLightUserdata(handler);
    l.pushClosure(zlua.wrap(disconnectUpdate), 2);

    return 1;
}

pub fn sceneAddObject(l: *Lua) i32 {
    const self = l.checkUserdata(Scene, 1, "Scene");
    const object = l.checkUserdata(Object, 2, "Object");
    self.addObject(object.*) catch {
        l.raiseErrorStr("out of memory", .{});
        return 0;
    };

    return 0;
}

pub fn sceneRemoveObject(l: *Lua) i32 {
    const self = l.checkUserdata(Scene, 1, "Scene");
    const object = l.checkUserdata(Object, 2, "Object");
    self.removeObject(object);

    return 0;
}

pub fn disconnectUpdate(l: *Lua) i32 {
    const scene = l.toUserdata(Scene, Lua.upvalueIndex(1)) catch unreachable;
    const handler = @as(*UpdateHandler, @ptrCast(@alignCast(
        l.toUserdata(anyopaque, Lua.upvalueIndex(2)) catch unreachable
    )));

    if (!handler.disconnected) {
        handler.disconnected = true;
        scene.removeUpdateCallback(handler);

        l.unref(zlua.registry_index, handler.ref);
        allocator.destroy(handler);
    }

    return 0;
}

pub fn register(l: *Lua, a: std.mem.Allocator) !void {
    allocator = a;

    // Scene object
    try l.newMetatable("Scene");
    l.setFuncs(&scene_methods, 0);
    l.pop(1);

    // Scene library
    l.newTable();
    l.setFuncs(&scene_lib, 0);
    l.setGlobal("Scene");
}
