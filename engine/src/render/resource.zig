// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../gpu/gpu.zig");

// Used by passes
pub const color_target: ResourceRef = .fromName("color_target");
pub const depth_buffer: ResourceRef = .fromName("depth_buffer");
pub const lights_buffer: ResourceRef = .fromName("lights_buffer");
pub const light_grid: ResourceRef = .fromName("light_grid");
pub const light_index_list: ResourceRef = .fromName("light_index_list");
pub const default_image: ResourceRef = .fromName("default_image");
pub const default_sampler: ResourceRef = .fromName("default_sampler");

pub const ResourceKind = enum { image, buffer, storage_buffer, sampler };
pub const ResourceHandle = union(ResourceKind) {
    image: gpu.types.ImageHandle,
    buffer: gpu.types.BufferHandle,
    storage_buffer: gpu.types.BufferHandle,
    sampler: gpu.types.SamplerHandle
};

pub const ResourceRef = struct {
    id: u64,
    name: []const u8,

    pub fn fromName(name: []const u8) ResourceRef {
        return .{ .id = std.hash.Wyhash.hash(420, name), .name = name };
    }
};

pub const ResourceTable = struct {
    map: std.AutoHashMap(u64, ResourceHandle),

    pub fn init(allocator: std.mem.Allocator) ResourceTable {
        return .{ .map = .init(allocator) };
    }

    pub fn deinit(self: *ResourceTable) void {
        self.map.deinit();
    }

    pub fn put(self: *ResourceTable, ref: ResourceRef, handle: ResourceHandle) !void {
        try self.map.put(ref.id, handle);
    }

    pub fn get(self: *ResourceTable, ref: ResourceRef, comptime kind: ResourceKind) ?switch (kind) {
        .image => gpu.types.ImageHandle,
        .buffer => gpu.types.BufferHandle,
        .storage_buffer => gpu.types.BufferHandle,
        .sampler => gpu.types.SamplerHandle
    } {
        const handle = self.map.get(ref.id) orelse return null;
        return switch (handle) {
            kind => |v| v,
            else => blk: { std.log.err("invalid type", .{}); break :blk null; },
        };
    }
};