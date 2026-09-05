// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const math = @import("../core/core.zig").math;
const assets = @import("../assets/assets.zig");

pub const DrawKind = enum { image_plane, mesh_untextured, mesh_textured };

pub const DrawItem = struct {
    kind: DrawKind,
    model: math.Mat4,
    mesh: ?assets.AssetHandle,
    image: ?assets.AssetHandle
};