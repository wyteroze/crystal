// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub const Vertex = extern struct {
    position: [3]f32,
    normal: [3]f32,
    uv: [2]f32
};

pub const Mesh = struct {
    path: []const u8,
    vertices: []Vertex,
    indices: []u32,

    pub fn deinit(self: *const Mesh, allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.indices);
        allocator.free(self.path);
    }
};

pub const Image = struct {
    width: usize, 
    height: usize,
    path: []const u8,
    data: []f32,

    pub fn deinit(self: *const Image, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.data);
    }
};

pub const ScriptSource = struct {
    path: []const u8,
    type: enum { text, bytecode, text_or_bytecode },
    data: []const u8,

    pub fn deinit(self: *const ScriptSource, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        allocator.free(self.path);
    }
};