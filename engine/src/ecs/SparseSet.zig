// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Entity = @import("Entity.zig");
const ComponentId = @import("ComponentId.zig");
const ComponentRegistry = @import("ComponentRegistry.zig");

const SparseSet = @This();
allocator: std.mem.Allocator,
component_id: ComponentId,
elem_align: u32,
elem_size: u32,
dtor: ?*const fn (bytes: []u8) void,
fields: []const ComponentId.FieldDesc,

sparse: std.ArrayList(u32),
dense: std.ArrayList(Entity),
dense_data: std.ArrayList(u8),

const null_idx = std.math.maxInt(u32);

pub fn init(allocator: std.mem.Allocator, info: ComponentRegistry.ComponentInfo, component_id: ComponentId) SparseSet {
    return .{ .allocator = allocator, .component_id = component_id, .elem_size = info.size, .elem_align = info.alignment, .dtor = info.dtor, .fields = info.fields, .sparse = .empty, .dense = .empty, .dense_data = .empty };
}

pub fn deinit(self: *SparseSet) void {
    var i: usize = 0;
    while (i < self.dense.items.len) : (i += 1) {
        const bytes = self.dense_data.items[i * self.elem_size ..][0..self.elem_size];

        for (self.fields) |field| {
            if (field.type.free) |free_fn| {
                free_fn(self.allocator, bytes[field.offset..][0..field.totalSize()]);
            }
        }

        if (self.dtor) |dtor| dtor(bytes);
    }

    self.sparse.deinit(self.allocator);
    self.dense.deinit(self.allocator);
    self.dense_data.deinit(self.allocator);
}

fn ensureCapacity(self: *SparseSet, idx: u32) !void {
    if (idx < self.sparse.items.len) return;
    const old_len = self.sparse.items.len;

    try self.sparse.resize(self.allocator, idx + 1);
    for (self.sparse.items[old_len..]) |*s| s.* = null_idx;
}

pub fn has(self: *SparseSet, entity: Entity) bool {
    if (entity.index >= self.sparse.items.len) return false;
    return self.sparse.items[entity.index] != null_idx;
}

pub fn insert(self: *SparseSet, entity: Entity, bytes: []const u8) !void {
    try self.ensureCapacity(entity.index);

    if (self.sparse.items[entity.index] != null_idx) {
        const dense_idx = self.sparse.items[entity.index];

        @memcpy(self.dense_data.items[dense_idx * self.elem_size ..][0..self.elem_size], bytes);
        return;
    }

    const dense_idx: u32 = @intCast(self.dense.items.len);
    try self.dense.append(self.allocator, entity);
    try self.dense_data.appendSlice(self.allocator, bytes);

    self.sparse.items[entity.index] = dense_idx;
}

/// Does nothing if the entity doesn't exist
pub fn remove(self: *SparseSet, entity: Entity) void {
    if (entity.index >= self.sparse.items.len) return;
    const dense_idx = self.sparse.items[entity.index];
    if (dense_idx == null_idx) return;

    const bytes = self.dense_data.items[dense_idx * self.elem_size ..][0..self.elem_size];

    for (self.fields) |f| {
        if (f.type.free) |free| {
            free(self.allocator, bytes[f.offset..][0..f.totalSize()]);
        }
    }

    if (self.dtor) |dtor| {
        dtor(bytes);
    }

    const last_idx: u32 = @intCast(self.dense.items.len - 1);
    if (dense_idx != last_idx) {
        const last_entity = self.dense.items[last_idx];
        self.dense.items[dense_idx] = last_entity;

        const src = self.dense_data.items[last_idx * self.elem_size ..][0..self.elem_size];
        const dst = self.dense_data.items[dense_idx * self.elem_size ..][0..self.elem_size];
        @memcpy(dst, src);

        self.sparse.items[last_entity.index] = dense_idx;
    }

    self.dense.shrinkRetainingCapacity(last_idx);
    self.dense_data.shrinkRetainingCapacity(last_idx * self.elem_size);
    self.sparse.items[entity.index] = null_idx;
}

pub fn get(self: *SparseSet, entity: Entity) ?[]u8 {
    if (entity.index > self.sparse.items.len) return null;

    const dense_idx = self.sparse.items[entity.index];
    if (dense_idx == null_idx) return null;

    return self.dense_data.items[dense_idx * self.elem_size ..][0..self.elem_size];
}

pub fn count(self: *SparseSet) usize {
    return self.dense.items.len;
}

pub fn entities(self: *SparseSet) []Entity {
    return self.dense.items;
}
