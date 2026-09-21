// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const core = @import("../core/core.zig");
const math = core.math;
const gpu = @import("../gpu/gpu.zig");
const assets = @import("../assets/Assets.zig");

// TODO: Put this in a better place
pub const Text = struct {
    font: assets.AssetHandle,
    size: u32,
    content: []const u8,
    color: core.Color,

    /// Since all components' strings must be heap-allocated, this frees the last
    /// string and dupes the given string. You should use the same allocator
    /// for every setText call.
    pub fn setText(self: *Text, allocator: std.mem.Allocator, text: []const u8) !void {
        allocator.free(self.content);
        self.content = try allocator.dupe(u8, text);
    }
};

pub const Material = struct {
    image: assets.types.GpuImage,
    sampler: gpu.GpuDevice.GpuSampler,
};

pub const RenderObject = struct {
    model: math.Mat4,
    mesh: assets.types.GpuMesh,
    material: Material
};

pub const UiObject = struct {
    pos: [2]f32,
    size: [2]f32,
    color: core.Color,
    uv_pos: [2]f32 = @splat(0),
    // A UV size of 0 means that there is no texture, and this is
    // just a plain colored object.
    uv_size: [2]f32 = @splat(0),
    // These must both be defined at once,
    // one can't be null while the other isn't.
    sampler: ?gpu.types.SamplerHandle = null,
    texture: ?gpu.types.ImageHandle = null,
};

pub const RenderScene = struct {
    ui_objects: std.ArrayList(UiObject),
    objects: std.ArrayList(RenderObject),
    lights: std.ArrayList(gpu.types.GpuLight),
};

pub const RenderView = struct {
    viewport_size: [2]u32,
    view_matrix: math.Mat4,
    proj_matrix: math.Mat4,
};

pub const LightKind = enum { point, directional };
pub const PointLightParams = struct { radius: f32 };
pub const Light = struct {
    color: core.Color,
    intensity: f32,
    kind: union(LightKind) {
        point: PointLightParams,
        directional: void
    }
};