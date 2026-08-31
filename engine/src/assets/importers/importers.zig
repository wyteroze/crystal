// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

pub const mesh_assimp = @import("mesh_assimp.zig");

pub const ImportLocation = union(enum) {
    path: []const u8,
    bytes: []const u8
};