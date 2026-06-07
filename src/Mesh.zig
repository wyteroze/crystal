// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("types.zig");
const obj_parser = @import("parsers/obj.zig");
const Sprite = @import("Sprite.zig").Sprite;

const Vec3_SIMD = types.Vec3_SIMD;
const Vertex = types.Vertex;
const Face = types.Face;

pub const Mesh = struct {
    allocator: std.mem.Allocator,
    vertices: []Vertex,
    indices: []usize,
    faces: []types.Face,
    texture: ?*Sprite,

    pub fn init(
        allocator: std.mem.Allocator,
        vertices: []const Vertex,
        indices: []const usize,
        faces: []const Face,
        texture: ?*Sprite
    ) !Mesh {
        const v = try allocator.dupe(Vertex, vertices);
        errdefer allocator.free(v);

        const i = try allocator.dupe(usize, indices);
        errdefer allocator.free(i);

        const f = try allocator.dupe(Face, faces);
        errdefer allocator.free(f);

        return .{
            .allocator = allocator,
            .vertices = v,
            .indices = i,
            .faces = f,
            .texture = texture
        };
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Mesh {
        var file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);

        var buffer: [4096]u8 = undefined;

        var file_reader = file.reader(io, &buffer);
        const reader = &file_reader.interface;

        const mesh = try obj_parser.parseObj(allocator, reader);
        return mesh;
    }

    pub fn deinit(self: Mesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
        self.allocator.free(self.faces);
    }
};
