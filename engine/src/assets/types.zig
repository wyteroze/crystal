// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../gpu/gpu.zig");

pub const Vertex = extern struct {
    position: [3]f32,
    normal: [3]f32,
    uv: [2]f32
};

pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,

    pub fn deinit(self: *const Mesh, allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.indices);
    }
};

pub const Image = struct {
    width: usize, 
    height: usize,
    format: gpu.types.PixelFormat,
    data: []u8,

    pub fn bytes(self: *const Image, comptime T: type) []T {
        return std.mem.bytesAsSlice(T, self.data);
    }

    pub fn deinit(self: *const Image, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub const ScriptSource = struct {
    type: enum { text, bytecode, text_or_bytecode },
    data: []const u8,

    pub fn deinit(self: *const ScriptSource, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

// GPU-specific. Stored in GPU memory

pub const GpuMesh = struct {
    vertex_buffer: gpu.GpuDevice.GpuBuffer,
    index_buffer: gpu.GpuDevice.GpuBuffer,
    vertex_count: u32,
    index_count: u32,

    pub fn deinit(self: GpuMesh) void {
        self.vertex_buffer.deinit();
        self.index_buffer.deinit();
    }
};

pub const GpuImage = struct {
    handle: gpu.GpuDevice.GpuImage,

    pub fn deinit(self: GpuImage) void {
        self.handle.deinit();
    }
};