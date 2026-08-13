// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Entity = @import("Entity.zig");
const ComponentId = @import("ComponentId.zig");
const ComponentRegistry = @import("ComponentRegistry.zig");
const SystemRegistry = @import("SystemRegistry.zig");
const SparseSet = @import("SparseSet.zig");
const Query = @import("Query.zig");

const World = @This();
allocator: std.mem.Allocator,
components: ComponentRegistry,
storages: std.ArrayList(SparseSet),
systems: SystemRegistry,

generations: std.ArrayList(u32),
alive: std.ArrayList(bool),
free: std.ArrayList(u32),

pub fn init(allocator: std.mem.Allocator) World {
    return .{
        .allocator = allocator,
        .components = .init(allocator),
        .storages = .empty,
        .systems = .init(allocator),
        .generations = .empty,
        .alive = .empty,
        .free = .empty
    };
}

pub fn deinit(self: *World) void {
    for (self.storages.items) |*s| s.deinit();
    self.storages.deinit(self.allocator);
    self.components.deinit();
    self.systems.deinit();
    self.generations.deinit(self.allocator);
    self.alive.deinit(self.allocator);
    self.free.deinit(self.allocator);
}

// Components

pub fn registerComponentNative(self: *World, comptime T: type, name: []const u8) !ComponentId {
    const id = try self.components.registerNative(T, name);
    try self.ensurestorageFor(id);

    return id;
}

pub fn registerComponentLayout(self: *World, name: []const u8, fields: []ComponentId.FieldDesc) !ComponentId {
    const id = try self.components.registerLayout(name, fields);
    try self.ensurestorageFor(id);

    return id;
}

fn ensurestorageFor(self: *World, id: ComponentId) !void {
    while (self.storages.items.len <= id.value) {
        const temp_id: ComponentId = .{ .value = @intCast(self.storages.items.len) };
        try self.storages.append(self.allocator, .init(self.allocator, self.components.info(temp_id), temp_id));
    }
}

pub fn storageFor(self: *World, id: ComponentId) ?*SparseSet {
    if (id.value >= self.storages.items.len) return null;
    return &self.storages.items[id.value];
}

// Entities

pub fn spawnEntity(self: *World) !Entity {
    if (self.free.pop()) |idx| {
        self.alive.items[idx] = true;
        return .{ .index = idx, .generation = self.generations.items[idx] };
    }

    const idx: u32 = @intCast(self.generations.items.len);
    try self.generations.append(self.allocator, 0);
    try self.alive.append(self.allocator, true);

    return .{ .index = idx, .generation = 0 };
}

pub fn isEntityAlive(self: *World, entity: Entity) bool {
    if (entity.index >= self.alive.items.len) return false;

    return self.alive.items[entity.index]
        and self.generations.items[entity.index] == entity.generation;
}

pub fn destroyEntity(self: *World, entity: Entity) void {
    if (!self.isEntityAlive(entity)) return;
    for (self.storages.items) |*s| s.remove(entity);

    self.alive.items[entity.index]= false;
    self.generations.items[entity.index] +%= 1;
    self.free.append(self.allocator, entity.index) catch {};
}

// Components

pub fn addComponent(self: *World, entity: Entity, id: ComponentId, comptime T: type, value: T) !void {
    const storage = self.storageFor(id) orelse return error.UnknownComponent;
    const bytes = std.mem.asBytes(&value);

    try storage.insert(entity, bytes);
}

pub fn addComponentBytes(self: *World, entity: Entity, id: ComponentId, bytes: []const u8) !void {
    const storage = self.storageFor(id) orelse return error.UnknownComponent;
    try storage.insert(entity, bytes);
}

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

pub fn unregisterSystem(self: *World, name: []const u8) void {
    self.systems.unregister(name);
}

pub fn tickAllSystems(self: *World, dt: f32) void {
    self.systems.runAll(self, dt);
}
