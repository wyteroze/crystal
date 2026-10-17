// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const core = @import("../core/core.zig");
const math = core.math;
const gpu = @import("../gpu/gpu.zig");
const assets = @import("../assets/Assets.zig");

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
    // TopLeft, TopRight, BottomLeft, BottomRight
    corners: [4]f32 = @splat(0),
    // Top, Bottom, Left, Right
    borders: [4]f32 = @splat(0),
    border_color: core.Color = .fromRgbFloat(0, 0, 0, 0),
    // These must both be defined at once,
    // one can't be null while the other isn't.
    sampler: ?gpu.types.SamplerHandle = null,
    texture: ?gpu.types.ImageHandle = null,
    is_text: bool = false
};

pub const RenderScene = struct {
    ui_objects: []const UiObject,
    objects: []const RenderObject,
    lights: []const gpu.types.GpuLight,
    clear_color: core.Color = .fromRgbFloat(0, 0, 0, 1.0),
    ambient: core.Color = .fromRgbFloat(0.1, 0.1, 0.1, 1.0),
};

pub const RenderFrame = struct {
    viewport_size: [2]u32,
    scale: f32 = 1,
    view_matrix: math.Mat4,
    proj_matrix: math.Mat4,
};

pub const RenderViewRequest = struct {
    frame: RenderFrame,
    scene: RenderScene,
    render_view_id: u64,
};

pub const RenderWindowRequest = struct {
    window_id: u64,
    ui_objects: []const UiObject,
};

pub const RenderWindow = struct {
    swapchain: gpu.GpuDevice.GpuSwapchain,
    pixel_size: [2]u32,
    scale: f32,
    vsync: bool = true,

    pub fn resize(self: *RenderWindow, pixel_size: [2]u32, scale: f32) !void {
        // Minimized
        self.scale = scale;
        if (pixel_size[0] == 0 or pixel_size[1] == 0) {
            self.pixel_size = pixel_size;
            return;
        }

        if (std.mem.eql(u32, &self.pixel_size, &pixel_size)) return;
        self.pixel_size = pixel_size;
        self.swapchain.resize(pixel_size);
    }
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