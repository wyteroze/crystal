// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

pub const types = @import("types.zig");
pub const importers = @import("importers/importers.zig");
pub const sources = @import("sources/sources.zig");
pub const pack = @import("pack/pack.zig");

pub const AssetRegistry = @import("AssetRegistry.zig");
pub const AssetHandle = @import("AssetHandle.zig");
pub const AssetKind = @import("AssetKind.zig");
pub const AssetId = @import("AssetId.zig");
pub const AssetUri = @import("AssetUri.zig");
pub const Cache = @import("Cache.zig");

const std = @import("std");
pub fn importMesh(allocator: std.mem.Allocator, path: [:0]const u8) !types.Mesh {
    return importers.mesh_assimp.importMesh(allocator, path);
}