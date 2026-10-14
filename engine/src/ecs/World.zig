// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Entity = @import("Entity.zig");
const ComponentId = @import("ComponentId.zig");
const ComponentRegistry = @import("ComponentRegistry.zig");
const SystemRegistry = @import("SystemRegistry.zig");
const SparseSet = @import("SparseSet.zig");
const Query = @import("Query.zig");
const Hierarchy = @import("Hierarchy.zig");
const signal = @import("../core/signal.zig");
const lua_components = @import("lua_components.zig");

pub const WriteMode = enum { add, set, upsert };
pub const FieldTypeSpec = struct {
    name: []const u8,
    type_name: []const u8
};

pub const UpdateSignal = signal.Signal(.{ f32 });
pub const DestroySignal = signal.Signal(.{});

const World = @This();
allocator: std.mem.Allocator,
components: ComponentRegistry,
storages: std.ArrayList(SparseSet),
systems: SystemRegistry,

generations: std.ArrayList(u32),
alive: std.ArrayList(bool),
free: std.ArrayList(u32),

hierarchy: Hierarchy,
changed_set: std.AutoHashMap(u64, void),

dispatcher: signal.Dispatcher,
update_signals: std.ArrayList(?*UpdateSignal),
destroy_signals: std.ArrayList(?*DestroySignal),

pub fn init(allocator: std.mem.Allocator) World {
    return .{
        .allocator = allocator,
        .components = .init(allocator),
        .storages = .empty,
        .systems = .init(allocator),
        .generations = .empty,
        .alive = .empty,
        .free = .empty,
        .dispatcher = .init(allocator),
        .update_signals = .empty,
        .destroy_signals = .empty,
        .hierarchy = .init(allocator),
        .changed_set = .init(allocator),
    };
}

pub fn deinit(self: *World) void {
    for (self.storages.items) |*s| s.deinit();
    self.hierarchy.deinit();
    self.changed_set.deinit();
    self.storages.deinit(self.allocator);
    self.components.deinit();
    self.systems.deinit();
    self.generations.deinit(self.allocator);
    self.alive.deinit(self.allocator);
    self.free.deinit(self.allocator);

    for (self.destroy_signals.items) |ds| if (ds) |s| s.destroy();
    for (self.update_signals.items) |us| if (us) |s| s.destroy();
    self.dispatcher.deinit();
    self.destroy_signals.deinit(self.allocator);
    self.update_signals.deinit(self.allocator);
}

// Components

pub fn registerComponent(self: *World, comptime T: type, name: []const u8) !ComponentId {
    const id = try self.components.register(T, name);
    try self.ensureStorageFor(id);

    return id;
}

pub fn registerLuaComponent(self: *World, name: []const u8) !ComponentId {
    const lc = lua_components;
    const id = try self.components.registerRaw(name, lc.type_name, @sizeOf(lc.LuaValue), @alignOf(lc.LuaValue), lc.freeLuaValue);
    try self.ensureStorageFor(id);

    return id;
}

fn ensureStorageFor(self: *World, id: ComponentId) !void {
    while (self.storages.items.len <= id.value) {
        const temp_id: ComponentId = .{ .value = @intCast(self.storages.items.len) };
        try self.storages.append(self.allocator, .init(self.allocator, self.components.info(temp_id), temp_id));
    }
}

pub fn set(self: *World, entity: Entity, id: ComponentId, comptime T: type, value: T) !void {
    const storage = self.storageFor(id) orelse return error.UnknownComponent;
    std.debug.assert(@sizeOf(T) == storage.info.size);

    try storage.insert(entity, std.mem.asBytes(&value));
    try self.markChanged(entity);
}

pub fn setRaw(self: *World, entity: Entity, id: ComponentId, bytes: []const u8) !void {
    if (!self.isEntityAlive(entity)) return error.DeadEntity;
    const storage = self.storageFor(id) orelse return error.UnknownComponent;
    std.debug.assert(bytes.len == storage.info.size);

    try storage.insert(entity, bytes);
    try self.markChanged(entity);
}

pub fn markChanged(self: *World, e: Entity) !void {
    if (self.changed_set.contains(e.toU64())) return;
    try self.changed_set.put(e.toU64(), {});

    try self.hierarchy.changed.append(self.allocator, e);
}

pub fn storageFor(self: *World, id: ComponentId) ?*SparseSet {
    if (id.value >= self.storages.items.len) return null;
    return &self.storages.items[id.value];
}

pub fn getComponents(self: *World, entity: Entity) ![]ComponentId {
    var components: std.ArrayList(ComponentId) = .empty;
    errdefer components.deinit(self.allocator);

    for (self.storages.items, 0..) |*s, i| {
        if (s.has(entity)) {
            try components.append(self.allocator, .{ .value = @intCast(i) });
        }
    }

    return components.toOwnedSlice(self.allocator);
}

// Entities

pub fn spawnEntity(self: *World) !Entity {
    if (self.free.pop()) |idx| {
        self.alive.items[idx] = true;

        const e: Entity = .{
            .index = idx,
            .generation = self.generations.items[idx],
            .world = self
        };

        try self.hierarchy.changed.append(self.allocator, e);
        return e;
    }

    const idx: u32 = @intCast(self.generations.items.len);
    try self.generations.append(self.allocator, 0);
    try self.alive.append(self.allocator, true);

    const e: Entity = .{
        .index = idx,
        .generation = 0,
        .world = self
    };
    
    try self.update_signals.append(self.allocator, null);
    try self.destroy_signals.append(self.allocator, null);
    try self.hierarchy.changed.append(self.allocator, e);

    return e;
}

pub fn isEntityAlive(self: *World, entity: Entity) bool {
    if (entity.index >= self.alive.items.len) return false;

    return self.alive.items[entity.index]
        and self.generations.items[entity.index] == entity.generation;
}

pub fn destroyEntity(self: *World, entity: Entity) void {
    if (!self.isEntityAlive(entity)) return;
    for (self.storages.items) |*s| s.remove(entity);

    if (self.destroy_signals.items[entity.index]) |s| {
        s.fire(.{});
        s.retire();
        self.destroy_signals.items[entity.index] = null;
    }
    if (self.update_signals.items[entity.index]) |s| {
        s.retire();
        self.update_signals.items[entity.index] = null;
    }
    self.alive.items[entity.index] = false;
    self.generations.items[entity.index] +%= 1;
    self.free.append(self.allocator, entity.index) catch {};
}

// Components

pub fn removeComponent(self: *World, entity: Entity, id: ComponentId) void {
    const storage = self.storageFor(id) orelse return;
    storage.remove(entity);
}

pub fn hasComponent(self: *World, entity: Entity, id: ComponentId) bool {
    const storage = self.storageFor(id) orelse return false;
    return storage.has(entity);
}

pub fn getComponent(self: *World, entity: Entity, id: ComponentId, comptime T: type) ?*T {
    const storage = self.storageFor(id) orelse return null;
    const bytes = storage.get(entity) orelse return null;

    return @ptrCast(@alignCast(bytes.ptr));
}

pub fn getComponentRaw(self: *World, entity: Entity, id: ComponentId) ?[]u8 {
    const storage = self.storageFor(id) orelse return null;
    return storage.get(entity);
}

// Queries, systems

pub fn query(self: *World, required: []const ComponentId) Query {
    return .init(self, required);
}

pub fn registerSystem(
    self: *World,
    name: []const u8,
    comptime Ctx: type,
    comptime run_fn: fn (world: *World, dt: f32, ctx: *Ctx) void,
    ctx_ptr: *Ctx
) !void {
    try self.systems.register(name, Ctx, run_fn, ctx_ptr);
}

pub fn registerSystemErased(self: *World, name: []const u8, run: SystemRegistry.SystemFn, ctx: *anyopaque, dtor: ?*const fn (allocator: std.mem.Allocator, ctx: *anyopaque) void) !void {
    try self.systems.registerErased(name, run, ctx, dtor);
}

pub fn unregisterSystem(self: *World, name: []const u8) void {
    self.systems.unregister(name);
}

pub fn update(self: *World, dt: f32) void {
    for (self.update_signals.items) |sig| if (sig) |s| s.fire(.{ dt });
    self.systems.runAll(self, dt);
    self.dispatcher.flush();
}

// Signal stuff

pub fn updatedSignal(self: *World, entity: Entity) !*UpdateSignal {
    if (!self.isEntityAlive(entity)) return error.DeadEntity;

    const slot = &self.update_signals.items[entity.index];
    if (slot.* == null) slot.* = try UpdateSignal.create(self.allocator, &self.dispatcher);

    return slot.*.?;
}

pub fn destroyedSignal(self: *World, entity: Entity) !*DestroySignal {
    if (!self.isEntityAlive(entity)) return error.DeadEntity;

    const slot = &self.destroy_signals.items[entity.index];
    if (slot.* == null) slot.* = try DestroySignal.create(self.allocator, &self.dispatcher);

    return slot.*.?;
}

pub fn format(
    _: *const @This(),
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try writer.print("World", .{ });
}

// pub const __lua = .ref;
// // this is so ugly man..
// pub const registerLua = struct {
//     const linker = @import("../scripting/linker/linker.zig");

//     const query_iter_metatable_name = "World.QueryIterator";
//     const binding = linker.Binding(World, true);

//     const LuaSystemCtx = struct {
//         lua: *zlua.Lua,
//         table_ref: i32,
//         query: []ComponentId,
//         name: []const u8
//     };

//     const LuaQueryIterator = struct {
//         world: *World,
//         required: []ComponentId,
//         iter: Query.Iterator
//     };

//     fn luaSystemTrampoline(world: *World, dt: f32, ctx: *anyopaque) void {
//         const ctx_typed: *LuaSystemCtx = @ptrCast(@alignCast(ctx));
//         const lua = ctx_typed.lua;

//         _ = lua.getIndexRaw(zlua.registry_index, ctx_typed.table_ref);
//         _ = lua.getField(-1, "Tick");
//         lua.pushValue(-2);
//         binding.push(lua, world);
//         lua.pushNumber(dt);

//         lua.protectedCall(.{ .args = 3, .results = 0 }) catch {
//             const msg = lua.toString(-1) catch "<no message>";
//             std.log.err("Lua system '{s}' Tick error: {s}", .{ ctx_typed.name, msg });

//             lua.pop(1);
//         };
//         lua.pop(1);
//     }

//     fn parseComponentIdList(lua: *zlua.Lua, self: *World, list_idx: i32) []ComponentId {
//         var out: std.ArrayList(ComponentId) = .empty;

//         const len = lua.lenRaw(list_idx);
//         var i: usize = 1;
//         while (i <= len) : (i += 1) {
//             _ = lua.getIndexRaw(list_idx, @intCast(i));
//             const comp_name = lua.toString(-1)
//                 catch lua.raiseErrorStr("component list can only contain component names (strings)", .{});
//             const comp_id = self.components.id(comp_name)
//                 orelse lua.raiseErrorStr("unknown component '%s' in component list", .{ comp_name.ptr });
//             out.append(self.allocator, comp_id)
//                 catch lua.raiseErrorStr("out of memory", .{});

//             lua.pop(1);
//         }

//         return out.toOwnedSlice(self.allocator)
//             catch lua.raiseErrorStr("out of memory", .{});
//     }

//     fn luaSystemDtor(allocator: std.mem.Allocator, ctx: *anyopaque) void {
//         const ctx_typed: *LuaSystemCtx = @ptrCast(@alignCast(ctx));
//         ctx_typed.lua.unref(zlua.registry_index, ctx_typed.table_ref);
//         allocator.free(ctx_typed.query);
//         allocator.free(ctx_typed.name);
//         allocator.destroy(ctx_typed);
//     }

//     fn luaQueryNext(lua: *zlua.Lua) i32 {
//         const box = lua.toUserdata(LuaQueryIterator, zlua.Lua.upvalueIndex(1)) catch unreachable;
//         const entity = box.iter.next() orelse {
//             lua.pushNil();
//             return 1;
//         };

//         lua.pushInteger(@intCast(box.iter.cursor));
//         linker.Binding(Entity, false).push(lua, entity);
//         return 2;
//     }

//     fn luaQueryIterGc(lua: *zlua.Lua) i32 {
//         const box = lua.toUserdata(LuaQueryIterator, 1) catch return 0;
//         box.world.allocator.free(box.required);
//         return 0;
//     }

//     fn registerComponentLua(self: *World, name: []u8, fields: []struct { name: []u8, type: []u8 }) !ComponentId {
//         const specs = try self.allocator.alloc(FieldTypeSpec, fields.len);
//         defer self.allocator.free(specs);

//         for (fields, 0..) |f, i| {
//             specs[i] = .{ .name = f.name, .type_name = f.type };
//         }

//         return self.registerComponentFromSpecs(name, specs);
//     }

//     fn registerSystemLua(lua: *zlua.Lua) i32 {
//         const self = binding.check(lua, 1);

//         _ = lua.getField(2, "Name");
//         const name = lua.toString(-1) catch lua.raiseErrorStr("'Name' field invalid or missing from system", .{});
//         const name_owned = self.allocator.dupe(u8, name) catch lua.raiseErrorStr("out of memory", .{});
//         lua.pop(1);

//         _ = lua.getField(2, "Query");
//         const query_list = parseComponentIdList(lua, self, lua.getTop());
//         lua.pop(1);

//         _ = lua.getField(2, "Tick");
//         if (!lua.isFunction(-1)) lua.raiseErrorStr("'Tick' function is invalid or missing from system", .{});
//         lua.pop(1);

//         lua.pushValue(2);
//         const table_ref = lua.ref(zlua.registry_index);

//         const ctx = self.allocator.create(LuaSystemCtx) catch lua.raiseErrorStr("out of memory", .{});
//         ctx.* = .{
//             .lua = lua,
//             .table_ref = table_ref,
//             .query = query_list,
//             .name = name_owned
//         };

//         self.registerSystemErased(name_owned, luaSystemTrampoline, @ptrCast(ctx), luaSystemDtor) catch lua.raiseErrorStr("failed to register system", .{});

//         return 0;
//     }

//     fn queryLua(lua: *zlua.Lua) i32 {
//         const self = binding.check(lua, 1);

//         const required_owned = parseComponentIdList(lua, self, 2);
//         const q: Query = .init(self, required_owned);

//         const box = lua.newUserdata(LuaQueryIterator);
//         box.* = .{ .world = self, .required = required_owned, .iter = q.iterator() };

//         if (lua.newMetatable(query_iter_metatable_name)) {
//             lua.pushFunction(zlua.wrap(luaQueryIterGc));
//             lua.setField(-2, "__gc");
//         } else |_| {}
//         lua.setMetatable(-2);

//         lua.pushClosure(zlua.wrap(luaQueryNext), 1);
//         lua.pushNil(); 
//         lua.pushNil();

//         return 3;
//     }

//     pub fn registerLua(l: anytype) void {
//         linker.reference(l, World, .{
//             .name = .{ .named = "World" },
//             .scope = .{ .module = "ecs.world" },
//             .methods = &.{
//                 .named("SpawnEntity", World.spawnEntity),
//                 .named("RegisterComponent", registerComponentLua),
//                 .custom("RegisterSystem", registerSystemLua),
//                 .custom("Query", queryLua)
//             },

//         });
//     }
// }.registerLua;
