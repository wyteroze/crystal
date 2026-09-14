// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const core = @import("../core/core.zig");
const math = core.math;
const gpu = @import("../gpu/gpu.zig");
const assets = @import("../assets/assets.zig");

pub const Material = struct {
    image: assets.types.GpuImage,
    sampler: gpu.GpuDevice.GpuSampler,
};

pub const RenderObject = struct {
    model: math.Mat4,
    mesh: assets.types.GpuMesh,
    material: Material
};

pub const RenderScene = struct {
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