// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const World = @import("World.zig");
const ComponentId = @import("ComponentId.zig");

const Entity = @This();
world: *World,
index: u32,
generation: u32,

pub const invalid: Entity = .{ .world = undefined, .index = std.math.maxInt(u32), .generation = std.math.maxInt(u32) };

pub fn eql(a: Entity, b: Entity) bool {
    return a.index == b.index and a.generation == b.generation;
}

pub fn toU64(self: Entity) u64 {
    return (@as(u64, self.generation) << 32) | @as(u64, self.index);
}

pub fn fromU64(bits: u64) Entity {
    return .{ .world = undefined, .index = @truncate(bits), .generation = @truncate(bits >> 32) };
}

pub fn destroy(self: Entity) void {
    self.world.destroyEntity(self);
}

pub fn isAlive(self: Entity) bool {
    return self.world.isEntityAlive(self);
}

pub fn hasComponent(self: Entity, name: []const u8) bool {
    const comp_id = self.world.components.id(name) orelse return false;
    return self.world.hasComponent(self, comp_id);
}

pub fn removeComponent(self: Entity, name: []const u8) void {
    const comp_id = self.world.components.id(name) orelse return;
    self.world.removeComponent(self, comp_id);
}

/// Memory is owned by the caller!!!
pub fn getComponents(self: Entity) ![]ComponentId {
    return try self.world.getComponents(self);
}

pub fn addComponentField(self: Entity, comp_name: []const u8, bytes: []u8) !void {
    const comp_id = self.world.components.id(comp_name) orelse return error.UnknownComponent;
    if (self.world.hasComponent(self, comp_id)) return error.AlreadyHasComponent;

    const info = self.world.components.info(comp_id);
    if (info.fields.len != 1) return error.MultiFieldUnsupported;

    var storage_bytes: [64]u8 = std.mem.zeroes([64]u8);
    @memcpy(storage_bytes[info.fields[0].offset..][0..bytes.len], bytes);

    try self.world.addComponentBytes(self, comp_id, storage_bytes[0..info.size]);
}

pub fn setComponentField(self: Entity, comp_name: []const u8, bytes: []const u8) !void {
    const comp_id = self.world.components.id(comp_name) orelse return error.UnknownComponent;
    if (!self.world.hasComponent(self, comp_id)) return error.NoSuchComponent;

    const info = self.world.components.info(comp_id);
    if (info.fields.len != 1) return error.MultiFieldUnsupported;

    const field = info.fields[0];
    const storage = self.world.getComponentRaw(self, comp_id) orelse return error.NoSuchComponent;
    const region = storage[field.offset..][0..field.totalSize()];

    if (field.type.free) |free_fn| free_fn(self.world.allocator, region);
    @memcpy(region, bytes);
}

pub fn getComponentFieldBytes(self: Entity, comp_name: []const u8) !?[]u8 {
    const comp_id = self.world.components.id(comp_name) orelse return error.UnknownComponent;
    const info = self.world.components.info(comp_id);
    if (info.fields.len != 1) return error.MultiFieldUnsupported;

    const storage = self.world.getComponentRaw(self, comp_id) orelse return null;
    const field = info.fields[0];

    return storage[field.offset..][0..field.totalSize()];
}

pub fn getParent(self: Entity) ?Entity {
    return self.world.hierarchy.getParent(self);
}

pub fn setParent(self: Entity, parent: ?Entity) !void {
    try self.world.hierarchy.setParent(self, parent);
}

pub fn isAncestorOf(self: Entity, ancestor: Entity) bool {
    return self.world.hierarchy.isAncestorOf(self, ancestor);
}

pub fn getChildren(self: Entity) []const Entity {
    return self.world.hierarchy.getChildren(self);
}

pub fn getComponent(self: Entity, id: ComponentId, comptime T: type) ?*T {
    return self.world.getComponent(self, id, T);
}

pub fn format(self: Entity, buf: []u8) []const u8 {
    return std.fmt.bufPrint(buf, "Entity{{ index: {d}, generation: {d} }}", .{ self.index, self.generation }) 
        catch "Entity{ index: ?, generation: ? }";
}

pub const __lua = .val;
pub const registerLua = struct {
    const linker = @import("../scripting/linker/linker.zig");
    const zlua = @import("zlua");
    const EntityBind = linker.Binding(Entity, false);
    const ChildrenSlidingWindowBind = linker.Binding(ChildrenSlidingWindow, true);
    const ComponentsSlidingWindowBind = linker.Binding(ComponentsSlidingWindow, true);

    // When indexing (`Children.xyz`): If key is string, get name of entity. If number, get ID
    // When setting (`Children.xyz = blah`): Error, this isn't valid
    // When iterating (`for i,v in pairs(Children) do`): Return an iterator
    // TODO: Detect when iterating over ChildrenSlidingWindow (__pairs), and return a Lua table
    // representing the contents of ChildrenSlidingWindow to avoid the lua <-> zig overhead.
    const ChildrenSlidingWindow = struct {
        allocator: std.mem.Allocator,
        entity: Entity,

        pub fn deinit(self: *ChildrenSlidingWindow) void {
            std.log.debug("collected", .{});
            self.allocator.destroy(self);
        }

        pub const __lua = .ref;
        pub fn format(self: *ChildrenSlidingWindow, buf: []u8) []const u8 {
            return std.fmt.bufPrint(buf, "ChildrenSlidingWindow {x}", .{ @intFromPtr(&self) })
                catch "ChildrenSlidingWindow ?";
        }

        pub fn set(l: *zlua.Lua) noreturn {
            l.raiseErrorStr("ChildrenSlidingWindow is read-only", .{});
        }

        pub fn get(l: *zlua.Lua) i32 {
            const self = ChildrenSlidingWindowBind.check(l, 1);
            if (l.typeOf(2) == .number) {
                const id = l.toInteger(2) catch unreachable;
                for (self.entity.getChildren()) |c| {
                    if (c.eql(.fromU64(@intCast(id)))) {
                        // found
                        EntityBind.push(l, c);
                        return 1;
                    }
                }

                // not found
                l.pushNil();
                return 1;
            } else if (l.typeOf(2) == .string) {
                const name = l.toString(2) catch unreachable;
                for (self.entity.getChildren()) |c| {
                    if (!c.hasComponent("Name")) continue;
                    const name_component_id = c.world.components.id("Name").?;
                    const entity_name = c.getComponent(name_component_id, []const u8).?;

                    if (std.mem.eql(u8, entity_name.*, name[0..name.len])) {
                        EntityBind.push(l, c);
                        return 1;
                    }
                }

                l.pushNil();
                return 1;
            } else {
                l.raiseErrorStr("attempt to index ChildrenSlidingWindow with '%s', only indexing via child name (string) or child id (number) is allowed", .{ l.typeNameIndex(2).ptr });
            }

            return 0;
        }
    };

    const ComponentsSlidingWindow = struct {
        allocator: std.mem.Allocator,
        entity: Entity,

        pub fn deinit(self: *ComponentsSlidingWindow) void {
            self.allocator.destroy(self);
        }

        pub const __lua = .ref;
        pub fn format(self: *ComponentsSlidingWindow, buf: []u8) []const u8 {
            return std.fmt.bufPrint(buf, "ComponentsSlidingWindow {x}", .{ @intFromPtr(&self) })
                catch "ComponentsSlidingWindow ?";
        }

        // These `set` and `get` metamethods are identical to luaSetComponent and luaGetComponent,
        // except they use a ComponentsSlidingWindowBind instead of a EntityBind for the `self` type
        pub fn set(l: *zlua.Lua) i32 {
            const self = ComponentsSlidingWindowBind.check(l, 1);
            const name = l.toString(2)  catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });
            const id = self.entity.world.components.id(name) orelse l.raiseErrorStr("unknown component '%s'", .{ name.ptr });
            const info = self.entity.world.components.info(id);
            if (info.fields.len != 1) l.raiseErrorStr("multi-field components not yet supported", .{});

            const field = info.fields[0];
            var bytes: [64]u8 = undefined;

            field.type.read(self.entity.world.allocator, l, 3, bytes[0..field.type.size]) catch |e| raiseForComponentErr(l, e, name);
            self.entity.setComponentField(name, bytes[0..field.type.size]) catch |e| raiseForComponentErr(l, e, name);
            return 0;
        }

        pub fn get(l: *zlua.Lua) i32 {
            const self = ComponentsSlidingWindowBind.check(l, 1);
            const name = l.toString(2)  catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });
            const id = self.entity.world.components.id(name) orelse l.raiseErrorStr("unknown component '%s'", .{ name.ptr });
            const info = self.entity.world.components.info(id);

            const bytes = self.entity.getComponentFieldBytes(name) catch |e| raiseForComponentErr(l, e, name);
            const b = bytes orelse {
                l.pushNil();
                return 1;
            };
            
            info.fields[0].type.write(l, b);
            return 1;
        }
    };

    fn raiseForComponentErr(lua: *zlua.Lua, err: anyerror, comp_name: [:0]const u8) noreturn {
        switch (err) {
            error.UnknownComponent => lua.raiseErrorStr("unknown component '%s'", .{ comp_name.ptr }),
            error.AlreadyHasComponent => lua.raiseErrorStr("entity already has component '%s'", .{ comp_name.ptr }),
            error.NoSuchComponent => lua.raiseErrorStr("entity has no component '%s'", .{ comp_name.ptr }),
            error.MultiFieldUnsupported => lua.raiseErrorStr("multi-field components not yet supported for '%s'", .{ comp_name.ptr }),
            error.NoLuaShape => lua.raiseErrorStr("component '%s' has no lua type layout", .{ comp_name.ptr }),
            error.OutOfMemory => lua.raiseErrorStr("out of memory", .{}),
            else => lua.raiseErrorStr("%s", .{ @errorName(err).ptr }),
        }
        unreachable;
    }

    fn luaAddComponent(lua: *zlua.Lua) i32 {
        const self = EntityBind.check(lua, 1);
        const comp_name = lua.checkString(2);
        const comp_id = self.world.components.id(comp_name) orelse lua.raiseErrorStr("unknown component '%s'", .{comp_name.ptr});
        const info = self.world.components.info(comp_id);
        if (info.fields.len != 1) lua.raiseErrorStr("multi-field components not yet supported", .{});

        const field = info.fields[0];
        var bytes: [64]u8 = undefined;
        field.type.read(self.world.allocator, lua, 3, bytes[0..field.type.size]) catch |e| raiseForComponentErr(lua, e, comp_name);
        self.addComponentField(comp_name, bytes[0..field.type.size]) catch |e| raiseForComponentErr(lua, e, comp_name);
        return 0;
    }

    fn luaSetComponent(lua: *zlua.Lua) i32 {
        const self = EntityBind.check(lua, 1);
        const comp_name = lua.checkString(2);
        const comp_id = self.world.components.id(comp_name) orelse lua.raiseErrorStr("unknown component '%s'", .{comp_name.ptr});
        const info = self.world.components.info(comp_id);
        if (info.fields.len != 1) lua.raiseErrorStr("multi-field components not yet supported", .{});

        const field = info.fields[0];
        var bytes: [64]u8 = undefined;

        field.type.read(self.world.allocator, lua, 3, bytes[0..field.type.size]) catch |e| raiseForComponentErr(lua, e, comp_name);
        self.setComponentField(comp_name, bytes[0..field.type.size]) catch |e| raiseForComponentErr(lua, e, comp_name);
        return 0;
    }

    fn luaSetComponents(lua: *zlua.Lua) i32 {
        const self = EntityBind.check(lua, 1);
        lua.checkType(2, .table);

        lua.pushNil();
        while (lua.next(2)) {
            if (lua.typeOf(-2) != .string) { lua.raiseErrorStr("invalid component name passed to SetComponents", .{}); unreachable; }
            const key = lua.toString(-2) catch |e| linker.util.luaErr(lua, e, .{ []const u8, -2 });

            const id = self.world.components.id(key) orelse lua.raiseErrorStr("unknown component '%s'", .{key.ptr});
            const info = self.world.components.info(id);
            if (info.fields.len != 1) lua.raiseErrorStr("multi-field components not yet supported", .{});

            const field = info.fields[0];
            var bytes: [64]u8 align(16) = undefined;
            std.debug.assert(field.type.alignment <= 16);
            std.debug.assert(field.type.size <= bytes.len);

            field.type.read(self.world.allocator, lua, -1, bytes[0..field.type.size]) catch |e| raiseForComponentErr(lua, e, key);
            self.setComponentField(key, bytes[0..field.type.size]) catch |e| raiseForComponentErr(lua, e, key);
            lua.pop(1);
        }

        return 0;
    }

    fn luaGetComponent(lua: *zlua.Lua) i32 {
        const self = EntityBind.check(lua, 1);
        const comp_name = lua.checkString(2);
        const comp_id = self.world.components.id(comp_name) orelse lua.raiseErrorStr("unknown component '%s'", .{comp_name.ptr});
        const info = self.world.components.info(comp_id);
        if (info.fields.len != 1) lua.raiseErrorStr("multi-field components not yet supported", .{});

        const bytes = self.getComponentFieldBytes(comp_name) catch |e| raiseForComponentErr(lua, e, comp_name);
        const b = bytes orelse {
            lua.pushNil();
            return 1;
        };
        
        info.fields[0].type.write(lua, b);
        return 1;
    }

    fn entityGet(l: *zlua.Lua) i32 {
        const self: Entity = EntityBind.check(l, 1);
        const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });

        if (std.mem.eql(u8, key, "Parent")) {
            if (self.getParent()) |p| {
                if (!p.eql(.invalid)) {
                    EntityBind.push(l, p);
                    return 1;
                }
            }

            l.pushNil();
            return 1;
        } else if (std.mem.eql(u8, key, "Components")) {
            const window = l.allocator().create(ComponentsSlidingWindow) catch |e| linker.util.luaErr(l, e, .{});
            window.* = .{
                .allocator = l.allocator(),
                .entity = self
            };

            ComponentsSlidingWindowBind.push(l, window);
            return 1;
        } else if (std.mem.eql(u8, key, "Children")) {
            const window = l.allocator().create(ChildrenSlidingWindow) catch |e| linker.util.luaErr(l, e, .{});
            window.* = .{
                .allocator = l.allocator(),
                .entity = self,
            };

            ChildrenSlidingWindowBind.push(l, window);
            return 1;
        } else if (std.mem.eql(u8, key, "Id")) {
            l.pushInteger(@intCast(self.toU64()));
            return 1;
        } else {
            // fallback to exising methods
            l.getMetatable(1) catch { l.pushNil(); return 1; };
            _ = l.getField(-1, "__methods");
            l.pushValue(2);
            _ = l.getTable(-2);

            return 1;
        }

        return 0;
    }

    fn entitySet(l: *zlua.Lua) i32 {
        const self = EntityBind.check(l, 1);
        const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });

        if (std.mem.eql(u8, key, "Parent")) {
            const entity = if (l.isNil(3)) null else blk: {
                const e = EntityBind.check(l, 3);
                if (!e.eql(.invalid)) break :blk e;
                break :blk null;
            };
            
            self.setParent(entity) catch |e| linker.util.luaErr(l, e, .{});
        } else if (std.mem.eql(u8, key, "Components")) {
            l.raiseErrorStr(
                \\attempt to set read-only property 'Components'
                \\hint: use methods like :AddComponent(), :SetComponent(), etc. on the entity instead
            , .{});
        } else if (std.mem.eql(u8, key, "Children")) {
            l.raiseErrorStr(
                \\attempt to set read-only property 'Children'
                \\hint: modifying world hierarchy is done by setting the `Parent`s of entities
            , .{});
        } else if (std.mem.eql(u8, key, "Id")) {
            l.raiseErrorStr("attempt to set read-only property 'Id'", .{});
        }

        return 0;
    }

    pub fn registerLua(l: *zlua.Lua) void {
        linker.reference(l, ChildrenSlidingWindow, .{
            .name = .auto,
            .scope = .{ .module = "ecs.entity" },
            .properties = .luaCustom(ChildrenSlidingWindow.get, ChildrenSlidingWindow.set),
            .tostring = .format(ChildrenSlidingWindow.format),
            .gc = .nonNamed(ChildrenSlidingWindow.deinit)
        });

        linker.reference(l, ComponentsSlidingWindow, .{
            .name = .auto,
            .scope = .{ .module = "ecs.entity" },
            .properties = .luaCustom(ComponentsSlidingWindow.get, ComponentsSlidingWindow.set),
            .tostring = .format(ComponentsSlidingWindow.format),
            .gc = .nonNamed(ComponentsSlidingWindow.deinit)
        });

        linker.reference(l, Entity, .{ 
            .name = .auto, 
            .scope = .{ .module = "ecs.entity" }, 
            .methods = &.{ 
                .named("Destroy", Entity.destroy), 
                .named("IsAlive", Entity.isAlive), 
                .named("HasComponent", Entity.hasComponent), 
                .named("RemoveComponent", Entity.removeComponent), 
                .custom("AddComponent", luaAddComponent), 
                .custom("SetComponent", luaSetComponent), 
                .custom("GetComponent", luaGetComponent),
                .custom("SetComponents", luaSetComponents)
            },
            .properties = .luaCustom(entityGet, entitySet),
            .tostring = .format(Entity.format) 
        });
    }
}.registerLua;