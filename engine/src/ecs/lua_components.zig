// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const ecs = @import("ecs.zig");
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

fn write(e: ecs.Entity, l: *zlua.Lua, codecs: []const ecs.Codec, name: []const u8, comptime mode: ecs.World.WriteMode) !void {
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

    var buf: [ecs.ComponentRegistry.max_component_size]u8 align(ecs.ComponentRegistry.max_alignment) = undefined;
    const bytes = buf[0..info.size];

    // Value is at stack index 3: (entity, name, value)
    if (std.mem.eql(u8, info.type_name, type_name)) {
        const v: LuaValue = .{ .l = l.mainThread(), .ref = l.ref(3) };
        @memcpy(bytes, std.mem.asBytes(&v));
    } else {
        const c = ecs.Codec.find(codecs, info.type_name) orelse return error.ComponentNotExposedToLua;
        c.read(l, 3, bytes);
    }

    try world.setRaw(e, id, bytes);
}

pub fn addComponent(e: ecs.Entity, l: *zlua.Lua, codecs: []const ecs.Codec, name: []const u8) !void {
    return write(e, l, codecs, name, .add);
}

pub fn setComponent(e: ecs.Entity, l: *zlua.Lua, codecs: []const ecs.Codec, name: []const u8) !void {
    return write(e, l, codecs, name, .upsert);
}

pub fn getComponent(e: ecs.Entity, l: *zlua.Lua, codecs: []const ecs.Codec, name: []const u8) !Pushed {
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

    const c = ecs.Codec.find(codecs, info.type_name) orelse return error.ComponentNotExposedToLua;
    if (c.push_component) |pc| { pc(l, e, id, bytes); return .{ .n = 1 }; }
    
    c.push(l, bytes);
    return .{ .n = 1 };
}

// "Proxy" object for `entity.Components`. 
pub const Components = struct {
    entity: ecs.Entity,

    pub fn index(self: Components, l: *zlua.Lua, codecs: []const ecs.Codec, name: []const u8) !Pushed {
        return getComponent(self.entity, l, codecs, name);
    }

    pub fn newindex(self: Components, l: *zlua.Lua, codecs: []const ecs.Codec, name: []const u8) !void {
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

pub const ComponentRef = struct {
    entity: ecs.Entity,
    id: ecs.ComponentId,

    fn codecAndBytes(self: ComponentRef, codecs: []const ecs.Codec) !struct { *const ecs.Codec, []u8 } {
        if (!self.entity.isAlive()) return error.DeadEntity;
        const w = self.entity.world;
        const info = w.components.info(self.id);

        const c = ecs.Codec.find(codecs, info.type_name) orelse return error.ComponentNotExposedToLua;
        const bytes = w.getComponentRaw(self.entity, self.id) orelse return error.ComponentMissing;

        return .{ c, bytes };
    }

    pub fn index(self: ComponentRef, l: *zlua.Lua, codecs: []const ecs.Codec, key: []const u8) !Pushed {
        const c, const bytes = try self.codecAndBytes(codecs);
        c.push(l, bytes);
        _ = l.pushString(key);
        _ = l.getTable(-2);
        l.remove(-2);
        
        return .{ .n = 1 };
    }

    pub fn newindex(self: ComponentRef, l: *zlua.Lua, codecs: []const ecs.Codec, key: []const u8) !void {
        const c, const bytes = try self.codecAndBytes(codecs);
        const w = self.entity.world;

        c.push(l, bytes);
        _ = l.pushString(key);
        l.pushValue(3);
        l.setTable(-3);

        var buf: [ecs.ComponentRegistry.max_component_size]u8 align(ecs.ComponentRegistry.max_alignment) = undefined;
        const out = buf[0..bytes.len];
        c.read(l, -1, out);
        l.pop(1);

        try w.setRaw(self.entity, self.id, out);
    }

    pub fn tostring(self: ComponentRef, l: *zlua.Lua, codecs: []const ecs.Codec) !Pushed {
        const c, const bytes = try self.codecAndBytes(codecs);

        c.push(l, bytes);
        _ = l.toStringEx(-1);
        l.remove(-2);

        return .{ .n = 1 };
    }
    
    // TODO: While this works at face value, it's inherently funky
    // because it wraps the real value of the component. While tostring() works,
    // stuff like typeof, iterators, etc. don't. Either find a solution that eliminates
    // the need for even having this, or make all needed metamethods fall back to the
    // underlying type's implementation of it. `ComponentRef` shouldn't even be a concept to Lua.
    pub const api = bind.value(ComponentRef, .{
        .name = "ComponentRef",
        .ops = .{
            .index = .{ .member = bind.func("index", ComponentRef.index) },
            .newindex = .{ .member = bind.func("newindex", ComponentRef.newindex) },
            .tostring = .{ .member = bind.func("tostring", ComponentRef.tostring) },
        },
    });
};