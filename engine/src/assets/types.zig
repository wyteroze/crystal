// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");

pub const Vertex = struct {
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
