// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("Types.zig");

pub const Mesh = struct {
    allocator: std.mem.Allocator,
    vertices: []@Vector(3, f32),
    indices: []u32,
    faces: []types.Face,

    pub fn init(allocator: std.mem.Allocator, vertices: []const @Vector(3, f32), indices: []const u32, faces: []const types.Face) !Mesh {
        return .{
            .allocator = allocator,
            .vertices = try allocator.dupe(@Vector(3, f32), vertices),
            .indices = try allocator.dupe(u32, indices),
            .faces = try allocator.dupe(types.Face, faces)
        };
    }

    pub fn deinit(self: Mesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
        self.allocator.free(self.faces);
    }
};
