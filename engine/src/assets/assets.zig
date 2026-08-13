// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("types.zig");
const importers = @import("importers/importers.zig");

pub const Mesh = types.Mesh;

pub fn importMesh(allocator: std.mem.Allocator, path: [:0]const u8) !Mesh {
    return importers.mesh_assimp.importMesh(allocator, path);
}
