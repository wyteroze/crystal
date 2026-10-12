// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Entity = @import("Entity.zig");
const ComponentId = @import("ComponentId.zig");
const ComponentInfo = @import("ComponentInfo.zig");
const ComponentRegistry = @import("ComponentRegistry.zig");

const SparseSet = @This();
allocator: std.mem.Allocator,
component_id: ComponentId,
info: *const ComponentInfo,
elem_size: u32,

sparse: std.ArrayList(u32),
dense: std.ArrayList(Entity),
dense_data: std.array_list.Aligned(u8, .@"16"),

const null_idx = std.math.maxInt(u32);

pub fn init(allocator: std.mem.Allocator, info: *const ComponentInfo, component_id: ComponentId) SparseSet {
    return .{ 
        .allocator = allocator, .component_id = component_id, .info = info, .elem_size = info.size,
        .sparse = .empty, .dense = .empty, .dense_data = .empty
    };
}

pub fn deinit(self: *SparseSet) void {
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
    const dense_idx = self.sparse.items[entity.index];
    if (dense_idx == null_idx) return false;
    return self.dense.items[dense_idx].eql(entity);
}

/// This takes ownership of the `bytes` and frees the previous value, if one exists.
pub fn insert(self: *SparseSet, entity: Entity, bytes: []const u8) !void {
    try self.ensureCapacity(entity.index);

    const existing = self.sparse.items[entity.index];
    if (existing != null_idx) {
        const dst = self.slot(existing);
        self.info.free(self.allocator, dst);
        @memcpy(dst[0..bytes.len], bytes);
        return;
    }

    const dense_idx: u32 = @intCast(self.dense.items.len);
    try self.dense.append(self.allocator, entity);
    const start = self.dense_data.items.len;
    try self.dense_data.resize(self.allocator, start + self.elem_size);
    @memset(self.dense_data.items[start..][0..self.elem_size], 0);
    @memcpy(self.dense_data.items[start..][0..bytes.len], bytes);
    self.sparse.items[entity.index] = dense_idx;
}

/// Does nothing if the entity doesn't exist
pub fn remove(self: *SparseSet, entity: Entity) void {
    if (entity.index >= self.sparse.items.len) return;
    const dense_idx = self.sparse.items[entity.index];
    if (dense_idx == null_idx or !self.dense.items[dense_idx].eql(entity)) return;

    self.info.free(self.allocator, self.slot(dense_idx));

    const last_idx: u32 = @intCast(self.dense.items.len - 1);
    if (dense_idx != last_idx) {
        const last_entity = self.dense.items[last_idx];
        self.dense.items[dense_idx] = last_entity;
        @memcpy(self.slot(dense_idx), self.slot(last_idx));
        self.sparse.items[last_entity.index] = dense_idx;
    }
    self.dense.shrinkRetainingCapacity(last_idx);
    self.dense_data.shrinkRetainingCapacity(last_idx * self.elem_size);
    self.sparse.items[entity.index] = null_idx;
}

pub fn get(self: *SparseSet, entity: Entity) ?[]u8 {
    if (entity.index >= self.sparse.items.len) return null;

    const dense_idx = self.sparse.items[entity.index];
    if (dense_idx == null_idx) return null;
    if (!self.dense.items[dense_idx].eql(entity)) return null;

    return self.dense_data.items[dense_idx * self.elem_size ..][0..self.elem_size];
}

pub fn count(self: *SparseSet) usize {
    return self.dense.items.len;
}

pub fn entities(self: *SparseSet) []Entity {
    return self.dense.items;
}

fn slot(self: *SparseSet, dense_idx: usize) []u8 {
    return self.dense_data.items[dense_idx * self.elem_size ..][0..self.elem_size];
}