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
    while (self.hierarchy.popChild(entity)) |c| self.destroyEntity(c);
    self.hierarchy.remove(entity);

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
