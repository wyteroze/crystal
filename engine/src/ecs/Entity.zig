// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const core = @import("../core/core.zig");
const signal = core.signal;
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

pub fn getName(self: Entity) ?[]const u8 {
    const id = self.world.components.id("Name") orelse return null;
    const c = self.world.getComponent(self, id, []const u8) orelse return null;

    return c.*;
}

pub fn updated(self: Entity) !*World.UpdateSignal {
    return self.world.updatedSignal(self);
}

pub fn destroyed(self: Entity) !*World.DestroySignal {
    return self.world.destroyedSignal(self);
}

pub fn format(
    self: @This(),
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try writer.print("Entity{{ index: {d}, generation: {d} }}", .{ self.index, self.generation });
}

const scripting = @import("../scripting/scripting.zig");
const bind = scripting.bind;
const lua_signal = scripting.lua_signal;
// Needs to be pub so the walker can find it.
pub const lua_components = @import("lua_components.zig");

pub const sub_api = bind.handle(Entity, .{
    .alive = bind.func("isAlive", Entity.isAlive),
    .methods = &.{
        bind.func("AddComponent", lua_components.addComponent),
        bind.func("SetComponent", lua_components.setComponent),
        bind.func("GetComponent", lua_components.getComponent),
        bind.func("HasComponent", Entity.hasComponent),
        bind.func("RemoveComponent", Entity.removeComponent)
    },
    .props = &.{
        bind.prop("Updated", struct {
            fn c(self: Entity) !lua_signal.Handle(World.UpdateSignal) {
                return .{ .signal = try self.updated() };
            }
        }.c, null),
        bind.prop("Destroyed", struct {
            fn c(self: Entity) !lua_signal.Handle(World.DestroySignal) {
                return .{ .signal = try self.destroyed() };
            }
        }.c, null),
        bind.readonly("Components", struct {
            fn c(self: Entity) lua_components.Components {
                return .{ .entity = self };
            }
        }.c)
    },
    .ops = .{ .eq = .{ .member = bind.func("eq", Entity.eql) }, .tostring = .auto }
});

// pub const luaBinding = struct {
//     const linker = @import("../scripting/linker/linker.zig");
//     const zlua = @import("zlua");
//     const EntityBind = linker.Binding(Entity, false);
//     const ChildrenSlidingWindowBind = linker.Binding(ChildrenSlidingWindow, true);
//     const ComponentsSlidingWindowBind = linker.Binding(ComponentsSlidingWindow, true);
//     const RefBind = linker.Binding(ComponentRef, false);

//     const ComponentRef = struct {
//         entity: Entity,
//         id: ComponentId,
        
//         pub const __lua = .val;
//         pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
//             try writer.print("ComponentRef{{ {f}, {d} }}", .{ self.entity, self.id.value });
//         }
//     };

//     fn refGet(l: *zlua.Lua) i32 {
//         const r = RefBind.check(l, 1);
//         const key = l.checkString(2);

//         r.entity.world.pushFieldToLua(r.entity, r.id, key, l) catch |e| raiseForComponentErr(l, e, key);
//         return 1;
//     }

//     fn refSet(l: *zlua.Lua) i32 {
//         const r = RefBind.check(l, 1);
//         const key = l.checkString(2);

//         r.entity.world.setFieldFromLua(r.entity, r.id, key, l, 3) catch |e| raiseForComponentErr(l, e, key);
//         return 0;
//     }

//     fn pushComponent(l: *zlua.Lua, entity: Entity, name: [:0]const u8) void {
//         const w = entity.world;
//         const id = w.components.id(name) orelse raiseForComponentErr(l, error.UnknownComponent, name);
//         if (!w.hasComponent(entity, id)) return l.pushNil();

//         if (w.components.info(id).isProxy()) {
//             RefBind.push(l, .{ .entity = entity, .id = id });
//         } else {
//             w.pushToLua(entity, name, l) catch |e| raiseForComponentErr(l, e, name);
//         }
//     }

//     pub fn applyComponentTable(
//         lua: *zlua.Lua,
//         entity: Entity,
//         table_idx: i32,
//         comptime skip: []const []const u8,
//         ensure: bool
//     ) void {
//         const abs_idx = lua.absIndex(table_idx);
//         const world = entity.world;

//         lua.pushNil();
//         next: while (lua.next(abs_idx)) {
//             if (lua.typeOf(-2) != .string) {
//                 lua.raiseErrorStr("component names must be strings", .{});
//                 unreachable;
//             }
//             const key = lua.toString(-2) catch |e| linker.util.luaErr(lua, e, .{ []const u8, -2 });

//             inline for (skip) |s| {
//                 if (std.mem.eql(u8, key, s)) {
//                     lua.pop(1);
//                     continue :next;
//                 }
//             }

//             world.setFromLua(entity, key, lua, -1, if (ensure) .upsert else .set) catch |e| raiseForComponentErr(lua, e, key);
//             lua.pop(1);
//         }
//     }

//     // When indexing (`Children.xyz`): If key is string, get name of entity. If number, get ID
//     // When setting (`Children.xyz = blah`): Error, this isn't valid
//     // When iterating (`for i,v in pairs(Children) do`): Return an iterator
//     // TODO: Detect when iterating over ChildrenSlidingWindow (__pairs), and return a Lua table
//     // representing the contents of ChildrenSlidingWindow to avoid the lua <-> zig overhead.
//     const ChildrenSlidingWindow = struct {
//         allocator: std.mem.Allocator,
//         entity: Entity,

//         pub fn deinit(self: *ChildrenSlidingWindow) void {
//             self.allocator.destroy(self);
//         }

//         pub const __lua = .ref;
//         pub fn format(
//             self: *const @This(),
//             writer: *std.Io.Writer,
//         ) std.Io.Writer.Error!void {
//             try writer.print("ChildrenSlidingWindow {x}", .{ @intFromPtr(&self) });
//         }

//         pub fn set(l: *zlua.Lua) noreturn {
//             l.raiseErrorStr("ChildrenSlidingWindow is read-only", .{});
//         }

//         pub fn get(l: *zlua.Lua) i32 {
//             const self = ChildrenSlidingWindowBind.check(l, 1);
//             if (l.typeOf(2) == .number) {
//                 const id = l.toInteger(2) catch unreachable;
//                 for (self.entity.getChildren()) |c| {
//                     if (c.eql(.fromU64(@intCast(id)))) {
//                         // found
//                         EntityBind.push(l, c);
//                         return 1;
//                     }
//                 }

//                 // not found
//                 l.pushNil();
//                 return 1;
//             } else if (l.typeOf(2) == .string) {
//                 const name = l.toString(2) catch unreachable;
//                 for (self.entity.getChildren()) |c| {
//                     if (c.getName()) |n| if (std.mem.eql(u8, n, name[0..name.len])) {
//                         EntityBind.push(l, c);
//                         return 1;
//                     };
//                 }

//                 l.pushNil();
//                 return 1;
//             } else {
//                 l.raiseErrorStr("attempt to index ChildrenSlidingWindow with '%s', only indexing via child name (string) or child id (number) is allowed", .{ l.typeNameIndex(2).ptr });
//             }

//             return 0;
//         }
//     };

//     const ComponentsSlidingWindow = struct {
//         allocator: std.mem.Allocator,
//         entity: Entity,

//         pub fn deinit(self: *ComponentsSlidingWindow) void {
//             self.allocator.destroy(self);
//         }

//         pub const __lua = .ref;
//         pub fn format(
//             self: *const @This(),
//             writer: *std.Io.Writer,
//         ) std.Io.Writer.Error!void {
//             try writer.print("ComponentsSlidingWindow {x}", .{ @intFromPtr(&self) });
//         }

//         pub fn set(l: *zlua.Lua) i32 {
//             const self = ComponentsSlidingWindowBind.check(l, 1);
//             const name = l.checkString(2);
            
//             self.entity.world.setFromLua(self.entity, name, l, 3, .upsert) catch |e| raiseForComponentErr(l, e, name);
//             return 0;
//         }

//         pub fn get(l: *zlua.Lua) i32 {
//             const self = ComponentsSlidingWindowBind.check(l, 1);
//             const name = l.checkString(2);

//             self.entity.world.pushToLua(self.entity, name, l) catch |e| raiseForComponentErr(l, e, name);
//             return 1;
//         }
//     };

//     pub fn raiseForComponentErr(lua: *zlua.Lua, err: anyerror, comp_name: [:0]const u8) noreturn {
//         switch (err) {
//             error.UnknownComponent => lua.raiseErrorStr("Unknown component '%s'", .{ comp_name.ptr }),
//             error.AlreadyHasComponent => lua.raiseErrorStr("Entity already has component '%s'", .{ comp_name.ptr }),
//             error.NoSuchComponent => lua.raiseErrorStr("Entity has no component '%s'", .{ comp_name.ptr }),
//             error.UnknownField => lua.raiseErrorStr("Unknown field '%s'", .{ Codec.bad_field.get().ptr }),
//             error.MissingField => lua.raiseErrorStr("Missing required field '%s'", .{ Codec.bad_field.get().ptr }),
//             error.DeadEntity => lua.raiseErrorStr("Entity is dead", .{}),
//             error.ComponentTypeMismatch => lua.raiseErrorStr("Component type mismatch", .{}),
//             error.NonStringKey => lua.raiseErrorStr("Component table keys must be strings", .{}),
//             error.ExpectedTable => lua.raiseErrorStr("Expected a table for component '%s'", .{ comp_name.ptr }),

//             error.OutOfMemory => std.debug.panic("Out of memory", .{}),
//             else => lua.raiseErrorStr("%s", .{ @errorName(err).ptr }),
//         }
//         unreachable;
//     }

//     fn luaAddComponent(lua: *zlua.Lua) i32 {
//         const self = EntityBind.check(lua, 1);
//         const name = lua.checkString(2);
//         self.world.setFromLua(self, name, lua, 3, .add) catch |e| raiseForComponentErr(lua, e, name);

//         return 0;
//     }

//     fn luaSetComponent(lua: *zlua.Lua) i32 {
//         const self = EntityBind.check(lua, 1);
//         const name = lua.checkString(2);
//         self.world.setFromLua(self, name, lua, 3, .set) catch |e| raiseForComponentErr(lua, e, name);

//         return 0;
//     }

//     fn luaSetComponents(lua: *zlua.Lua) i32 {
//         const self = EntityBind.check(lua, 1);
//         lua.checkType(2, .table);

//         applyComponentTable(lua, self, 2, &.{}, false);
//         return 0;
//     }

//     fn luaGetComponent(lua: *zlua.Lua) i32 {
//         const self = EntityBind.check(lua, 1);
//         const name = lua.checkString(2);
//         self.world.pushToLua(self, name, lua) catch |e| raiseForComponentErr(lua, e, name);

//         return 1;
//     }

//     fn entityGet(l: *zlua.Lua) i32 {
//         const self: Entity = EntityBind.check(l, 1);
//         const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });

//         if (std.mem.eql(u8, key, "Parent")) {
//             if (self.getParent()) |p| {
//                 if (!p.eql(.invalid)) {
//                     EntityBind.push(l, p);
//                     return 1;
//                 }
//             }

//             l.pushNil();
//             return 1;
//         } else if (std.mem.eql(u8, key, "Components")) {
//             const window = l.allocator().create(ComponentsSlidingWindow) catch |e| linker.util.luaErr(l, e, .{});
//             window.* = .{
//                 .allocator = l.allocator(),
//                 .entity = self
//             };

//             ComponentsSlidingWindowBind.push(l, window);
//             return 1;
//         } else if (std.mem.eql(u8, key, "Children")) {
//             const window = l.allocator().create(ChildrenSlidingWindow) catch |e| linker.util.luaErr(l, e, .{});
//             window.* = .{
//                 .allocator = l.allocator(),
//                 .entity = self,
//             };

//             ChildrenSlidingWindowBind.push(l, window);
//             return 1;
//         } else if (std.mem.eql(u8, key, "Id")) {
//             l.pushInteger(@intCast(self.toU64()));
//             return 1;
//         } else if (std.mem.eql(u8, key, "Events")) {
//             l.newTable();
//             linker.util.pushVal(l, *signal.Signal(.{ f32 }), self.updated());
//             l.setField(-2, "Updated");
//             linker.util.pushVal(l, *signal.Signal(.{}), self.destroyed());
//             l.setField(-2, "Destroyed");

//             return 1;
//         } else {
//             // fallback to exising methods
//             l.getMetatable(1) catch { l.pushNil(); return 1; };
//             _ = l.getField(-1, "__methods");
//             l.pushValue(2);
//             _ = l.getTable(-2);

//             return 1;
//         }

//         return 0;
//     }

//     fn entitySet(l: *zlua.Lua) i32 {
//         const self = EntityBind.check(l, 1);
//         const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });

//         if (std.mem.eql(u8, key, "Parent")) {
//             const entity = if (l.isNil(3)) null else blk: {
//                 const e = EntityBind.check(l, 3);
//                 if (!e.eql(.invalid)) break :blk e;
//                 break :blk null;
//             };
            
//             self.setParent(entity) catch |e| linker.util.luaErr(l, e, .{});
//         } else if (std.mem.eql(u8, key, "Components")) {
//             l.raiseErrorStr(
//                 \\attempt to set read-only property 'Components'
//                 \\hint: use methods like :AddComponent(), :SetComponent(), etc. on the entity instead
//             , .{});
//         } else if (std.mem.eql(u8, key, "Children")) {
//             l.raiseErrorStr(
//                 \\attempt to set read-only property 'Children'
//                 \\hint: modifying world hierarchy is done by setting the `Parent`s of entities
//             , .{});
//         } else if (std.mem.eql(u8, key, "Id")) {
//             l.raiseErrorStr("attempt to set read-only property 'Id'", .{});
//         }

//         return 0;
//     }

//     pub fn registerLua(l: *zlua.Lua) void {
//         // Updated
//         linker.signal(l, signal.Signal(.{ f32 }));
//         // Destroyed
//         linker.signal(l, signal.Signal(.{}));

//         linker.reference(l, ComponentRef, .{
//             .name = .auto,
//             .scope = .{ .module = "ecs.entity" },
//             .properties = .luaCustom(refGet, refSet),
//         });
        
//         linker.reference(l, ChildrenSlidingWindow, .{
//             .name = .auto,
//             .scope = .{ .module = "ecs.entity" },
//             .properties = .luaCustom(ChildrenSlidingWindow.get, ChildrenSlidingWindow.set),
//             .gc = .nonNamed(ChildrenSlidingWindow.deinit)
//         });

//         linker.reference(l, ComponentsSlidingWindow, .{
//             .name = .auto,
//             .scope = .{ .module = "ecs.entity" },
//             .properties = .luaCustom(ComponentsSlidingWindow.get, ComponentsSlidingWindow.set),
//             .gc = .nonNamed(ComponentsSlidingWindow.deinit)
//         });

//         linker.reference(l, Entity, .{ 
//             .name = .auto, 
//             .scope = .{ .module = "ecs.entity" }, 
//             .methods = &.{ 
//                 .named("Destroy", Entity.destroy), 
//                 .named("IsAlive", Entity.isAlive), 
//                 .named("HasComponent", Entity.hasComponent), 
//                 .named("RemoveComponent", Entity.removeComponent), 
//                 .custom("AddComponent", luaAddComponent), 
//                 .custom("SetComponent", luaSetComponent), 
//                 .custom("GetComponent", luaGetComponent),
//                 .custom("SetComponents", luaSetComponents)
//             },
//             .properties = .luaCustom(entityGet, entitySet),
//         });
//     }
// };

// pub const registerLua = luaBinding.registerLua;