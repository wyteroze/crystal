// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const Entity = @import("Entity.zig");
const World = @import("World.zig");
const ComponentRegistry = @import("ComponentRegistry.zig");
const Codec = @import("Codec.zig");
const bind = @import("../scripting/bind/bind.zig");
const Pushed = @import("../scripting/bind/wrap.zig").Pushed;

pub const type_name = "lua.Value";

pub const LuaValue = struct {
    l: *zlua.Lua,
    ref: i32
};

pub fn freeLuaValue(_: std.mem.Allocator, bytes: []u8) void {
    const v: *LuaValue = @ptrCast(@alignCast(bytes.ptr));
    v.l.unref(v.ref);
}

fn write(e: Entity, l: *zlua.Lua, codecs: []const Codec, name: []const u8, comptime mode: World.WriteMode) !void {
    if (!e.isAlive()) return error.DeadEntity;

    const world = e.world;
    const id = world.components.id(name) orelse return error.UnknownComponent;
    const info = world.components.info(id);

    const exists = world.hasComponent(e, id);
    switch (mode) {
        .add => if (exists) return error.ComponentAlreadyExists,
        .set => if (!exists) return error.ComponentMissing,
        .upsert => {}
    }

    var buf: [ComponentRegistry.max_component_size]u8 align(ComponentRegistry.max_alignment) = undefined;
    const bytes = buf[0..info.size];

    // Value is at stack index 3: (entity, name, value)
    if (std.mem.eql(u8, info.type_name, type_name)) {
        const v: LuaValue = .{ .l = l.mainThread(), .ref = l.ref(3) };
        @memcpy(bytes, std.mem.asBytes(&v));
    } else {
        const c = Codec.find(codecs, info.type_name) orelse return error.ComponentNotExposedToLua;
        c.read(l, 3, bytes);
    }

    try world.setRaw(e, id, bytes);
}

pub fn addComponent(e: Entity, l: *zlua.Lua, codecs: []const Codec, name: []const u8) !void {
    return write(e, l, codecs, name, .add);
}

pub fn setComponent(e: Entity, l: *zlua.Lua, codecs: []const Codec, name: []const u8) !void {
    return write(e, l, codecs, name, .upsert);
}

pub fn getComponent(e: Entity, l: *zlua.Lua, codecs: []const Codec, name: []const u8) !Pushed {
    const world = e.world;
    const id = world.components.id(name) orelse return error.UnknownComponent;
    const info = world.components.info(id);

    const bytes = world.getComponentRaw(e, id) orelse {
        l.pushNil();
        return .{ .n = 1 };
    };

    if (std.mem.eql(u8, info.type_name, type_name)) {
        const v: *LuaValue = @ptrCast(@alignCast(bytes.ptr));
        _ = l.getIndexRaw(zlua.registry_index, v.ref);
        return .{ .n = 1 };
    }

    const c = Codec.find(codecs, info.type_name) orelse return error.ComponentNotExposedToLua;
    c.push(l, bytes);
    return .{ .n = 1 };
}

// "Proxy" object for `entity.Components`. 
pub const Components = struct {
    entity: Entity,

    pub fn index(self: Components, l: *zlua.Lua, codecs: []const Codec, name: []const u8) !Pushed {
        return getComponent(self.entity, l, codecs, name);
    }

    pub fn newindex(self: Components, l: *zlua.Lua, codecs: []const Codec, name: []const u8) !void {
        return write(self.entity, l, codecs, name, .upsert);
    }

    pub const api = bind.value(Components, .{
        .name = "Components",
        .ops = .{
            .index = .{ .member = bind.func("index", Components.index) },
            .newindex = .{ .member = bind.func("newindex", Components.newindex) },
        },
    });
};