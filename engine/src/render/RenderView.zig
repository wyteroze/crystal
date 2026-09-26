// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("types.zig");
const gpu = @import("../gpu/gpu.zig");
const Renderer = @import("Renderer.zig");
// random kid:
const ecs = @import("../ecs/ecs.zig");

const RenderView = @This();
id: u64,
camera: ecs.Entity,
renderer: *Renderer,
target: gpu.GpuDevice.GpuImage,

pub fn init(renderer: *Renderer, size: [2]u32, id: u64, camera: ecs.Entity) !RenderView {
    return .{
        .id = id,
        .camera = camera,
        .renderer = renderer,
        .target = try renderer.gpu_device.createImage(.{
            .name = "RenderView target",
            .is_render_target = true,
            .width = size[0],
            .height = size[1],
            .format = .bgra8,
        })
    };
}

pub fn resize(self: *RenderView, new_size: [2]u32) !void {
    self.target.deinit();
    self.target = try self.gpu_device.createImage(.{
        .name = "RenderView target",
        .is_render_target = true,
        .width = new_size[0],
        .height = new_size[1],
        .format = .bgra8
    });
}

pub fn deinit(self: *RenderView) void {
    self.target.deinit();
}