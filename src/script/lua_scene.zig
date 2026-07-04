// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const log = @import("../log.zig").lua;
const Scene = @import("../Scene.zig").Scene;
const SceneRegistry = @import("../SceneRegistry.zig").SceneRegistry;
const Object = @import("../object.zig").Object;
const Lua = zlua.Lua;
var allocator: std.mem.Allocator = undefined;
var sceneRegistry: *SceneRegistry = undefined;
var current_scene_ref: ?i32 = null;

const ScenePtr = struct {
    ptr: *Scene,
    camera_ref: ?i32 = null,
    object_refs: std.AutoHashMap(*Object, i32) = undefined
};
const RefCtx = struct { lua: *Lua, ref: i32 };
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

    fn destroy(ctx: ?*anyopaque) void {
        const self = @as(*UpdateHandler, @ptrCast(@alignCast(ctx.?)));
        self.lua.unref(zlua.registry_index, self.ref);
        allocator.destroy(self);
    }
};

const scene_lib = [_]zlua.FnReg{
    .{ .name = "new", .func = zlua.wrap(sceneNew) }
};

const scene_methods = [_]zlua.FnReg{
    // Methods
    .{ .name = "OnUpdate", .func = zlua.wrap(sceneOnUpdate) },
    .{ .name = "AddObject", .func = zlua.wrap(sceneAddObject) },
    .{ .name = "RemoveObject", .func = zlua.wrap(sceneRemoveObject) },

    // Metamethods
    .{ .name = "__gc", .func = zlua.wrap(sceneGc) }
};

pub fn sceneNew(l: *Lua) i32 {
    const name = l.optString(1);
    const native_scene = allocator.create(Scene) catch {
        l.raiseErrorStr("out of memory creating scene", .{});
        return 0;
    };
    native_scene.* = Scene.init(allocator, name, null);

    const scene: *ScenePtr = l.newUserdata(ScenePtr, 0);
    scene.* = .{ .ptr = native_scene, .object_refs = std.AutoHashMap(*Object, i32).init(allocator) };
    l.setMetatableRegistry("Scene");
    l.pushValue(-1);

    sceneRegistry.addScene(native_scene) catch |e| {
        allocator.destroy(native_scene);
        l.raiseErrorStr("failed to add scene to registry: '%s'", .{ @errorName(e).ptr });
        return 0;
    };

    return 1;
}

 pub fn sceneLibNewIndex(l: *Lua) i32 {
     const key = l.checkString(2);

     if (std.mem.eql(u8, key, "CurrentScene")) {
         if (l.isNil(3)) {
             sceneRegistry.current_scene = null;

             if (current_scene_ref) |r| {
                 l.unref(zlua.registry_index, r);
                 current_scene_ref = null;
             }

             return 0;
         }

         const scene_data = l.checkUserdata(ScenePtr, 3, "Scene");
         sceneRegistry.current_scene = scene_data.ptr;

         if (current_scene_ref) |r| {
             l.unref(zlua.registry_index, r);
         }

         l.pushValue(3);
         current_scene_ref = l.ref(zlua.registry_index);

         return 0;
     }

     l.raiseErrorStr("no property named '%s' exists, you can not assign to it", .{ key.ptr });
     return 0;
 }

pub fn sceneLibIndex(l: *Lua) i32 {
    const key = l.checkString(2);

    if (std.mem.eql(u8, key, "CurrentScene")) {
        if (sceneRegistry.current_scene != null and current_scene_ref != null) {
            _ = l.getIndexRaw(zlua.registry_index, current_scene_ref.?);
            return 1;
        }

        l.pushNil();
        return 1;
    }

    l.raiseErrorStr("no property named '%s' exists", .{ key.ptr });
    return 0;
}

pub fn sceneIndex(l: *Lua) i32 {
    const self = l.checkUserdata(ScenePtr, 1, "Scene");
    const key = l.checkString(2);

    if (std.mem.eql(u8, key, "Camera")) {
        if (self.camera_ref) |r| {
            _ = l.getIndexRaw(zlua.registry_index, r);
            return 1;
        }

        l.pushNil();
        return 1;
    }

    _ = l.getField(zlua.registry_index, "Scene");
    l.pushValue(2);
    _ = l.getTable(-2);

    if (!l.isNil(-1)) {
        return 1;
    }

    l.raiseErrorStr("no property named '%s' exists", .{ key.ptr });
    return 0;
}

pub fn sceneNewIndex(l: *Lua) i32 {
    const self = l.checkUserdata(ScenePtr, 1, "Scene");
    const key = l.checkString(2);

    if (std.mem.eql(u8, key, "Camera")) {
        const obj = l.checkUserdata(Object, 3, "Object");
        switch (obj.data) {
            .camera => |c| {
                self.ptr.camera = c.camera;

                if (self.camera_ref) |r| {
                    l.unref(zlua.registry_index, r);
                }

                l.pushValue(3);
                self.camera_ref = l.ref(zlua.registry_index);
            },

            else => l.raiseErrorStr("expected 'Camera' but got '%s'", .{ obj.data.luaName().ptr })
        }

        return 0;
    }

    l.raiseErrorStr("no property named '%s' exists, you can not assign to it", .{ key.ptr });
    return 0;
}

pub fn sceneOnUpdate(l: *Lua) i32 {
    const self = l.checkUserdata(ScenePtr, 1, "Scene");

    l.checkType(2, .function);
    l.pushValue(2);
    const callback_ref = l.ref(zlua.registry_index);

    const handler = allocator.create(UpdateHandler) catch {
        l.raiseErrorStr("out of memory registering OnUpdate callback", .{});
        return 0;
    };

    handler.* = .{ .lua = l, .ref = callback_ref };
    self.ptr.addUpdateCallback(.{
        .ctx = handler,
        .func = UpdateHandler.call
    }) catch {
        l.raiseErrorStr("out of memory registering OnUpdate callback", .{});
        return 0;
    };

    l.pushValue(1);
    l.pushLightUserdata(handler);
    l.pushClosure(zlua.wrap(disconnectUpdate), 2);

    return 1;
}

pub fn sceneAddObject(l: *Lua) i32 {
    const self = l.checkUserdata(ScenePtr, 1, "Scene");
    const object = l.checkUserdata(Object, 2, "Object");
    self.ptr.addObject(object) catch {
        l.raiseErrorStr("out of memory", .{});
        return 0;
    };

    l.pushValue(2);
    const ref = l.ref(zlua.registry_index);
    self.object_refs.put(object, ref) catch {
        l.unref(zlua.registry_index, ref);
        l.raiseErrorStr("out of memory tracking object reference", .{});
        return 0;
    };

    return 0;
}

pub fn sceneRemoveObject(l: *Lua) i32 {
    const self = l.checkUserdata(ScenePtr, 1, "Scene");
    const object = l.checkUserdata(Object, 2, "Object");
    self.ptr.removeObject(object);

    if (self.object_refs.fetchRemove(object)) |entry| {
        l.unref(zlua.registry_index, entry.value);
    }

    return 0;
}

pub fn sceneGc(l: *Lua) i32 {
    const self = l.checkUserdata(ScenePtr, 1, "Scene");

    if (sceneRegistry.current_scene == self.ptr) {
        sceneRegistry.current_scene = null;

        if (current_scene_ref) |r| {
            l.unref(zlua.registry_index, r);
            current_scene_ref = null;
        }
    }

    if (self.camera_ref) |r| {
        l.unref(zlua.registry_index, r);
    }

    for (self.ptr.callbacks.items) |cb| {
        const handler = @as(*UpdateHandler, @ptrCast(@alignCast(cb.ctx.?)));
        UpdateHandler.destroy(handler);
    }

    var it = self.object_refs.iterator();
    while (it.next()) |entry| {
        l.unref(zlua.registry_index, entry.value_ptr.*);
    }

    self.object_refs.deinit();

    sceneRegistry.removeScene(self.ptr);
    return 0;
}

pub fn disconnectUpdate(l: *Lua) i32 {
    const scene = l.toUserdata(ScenePtr, Lua.upvalueIndex(1)) catch unreachable;
    const handler = @as(*UpdateHandler, @ptrCast(@alignCast(
        l.toUserdata(anyopaque, Lua.upvalueIndex(2)) catch unreachable
    )));

    if (!handler.disconnected) {
        handler.disconnected = true;
        scene.ptr.removeUpdateCallback(handler);
        UpdateHandler.destroy(handler);
    }

    return 0;
}

pub fn unrefScene(ctx: ?*anyopaque) void {
    const data = @as(*RefCtx, @ptrCast(@alignCast(ctx.?)));
    data.lua.unref(zlua.registry_index, data.ref);
    allocator.destroy(data);
}

pub fn register(l: *Lua, a: std.mem.Allocator, s: *SceneRegistry) !void {
    allocator = a;
    sceneRegistry = s;

    // Scene object
    try l.newMetatable("Scene");
    l.pushFunction(zlua.wrap(sceneIndex));
    l.setField(-2, "__index");
    l.pushFunction(zlua.wrap(sceneNewIndex));
    l.setField(-2, "__newindex");

    l.setFuncs(&scene_methods, 0);
    l.pop(1);

    // Scene library
    l.newTable();
    l.setFuncs(&scene_lib, 0);

    l.newTable();
    l.pushFunction(zlua.wrap(sceneLibIndex));
    l.setField(-2, "__index");
    l.pushFunction(zlua.wrap(sceneLibNewIndex));
    l.setField(-2, "__newindex");
    l.setMetatable(-2);

    l.setGlobal("Scene");
}
