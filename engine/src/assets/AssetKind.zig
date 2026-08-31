// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("types.zig");
const importers = @import("importers/importers.zig");

pub const AssetKind = union(enum) {
    mesh: types.Mesh,
    script_source: types.ScriptSource,

    pub fn parse(allocator: std.mem.Allocator, path: []const u8, bytes: []u8) !AssetKind {
        const ext = std.Io.Dir.path.extension(path);
        const path_owned = try allocator.dupe(u8, path);
        errdefer allocator.free(path_owned);

        if (std.mem.eql(u8, ext, ".obj") 
            or std.mem.eql(u8, ext, ".glb") 
            or std.mem.eql(u8, ext, ".gltf") 
            or std.mem.eql(u8, ext, ".stl") 
            or std.mem.eql(u8, ext, ".fbx")
        ) {
            defer allocator.free(bytes);

            return .{ .mesh = try importers.mesh_assimp.importMesh(allocator, .{ .bytes = bytes }, path_owned) };
        }

        if (std.mem.eql(u8, ext, ".lua")) {
            return .{ .script_source = .{ .type = .text, .data = bytes, .path = path_owned } };
        } else if (std.mem.eql(u8, ext, ".luac")) {
            return .{ .script_source = .{ .type = .bytecode, .data = bytes, .path = path_owned } };
        }

        std.log.err("unknown file type '{s}'", .{ ext });
        return error.UnknownFileType;
    }

    pub fn deinit(self: *AssetKind, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .mesh => |m| m.deinit(allocator),
            .script_source => |s| s.deinit(allocator)
        }
    }
};