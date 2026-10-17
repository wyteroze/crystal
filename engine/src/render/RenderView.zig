// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("types.zig");
const gpu = @import("../gpu/gpu.zig");
const Renderer = @import("Renderer.zig");
// random kid:
const ecs = @import("../ecs/ecs.zig");

const tile_size = Renderer.tile_size;
const max_lights_per_tile = Renderer.max_lights_per_tile;

const RenderView = @This();
id: u64,
size: [2]u32,
camera: ecs.Entity,
renderer: *Renderer,
target: gpu.GpuDevice.GpuImage,
depth: gpu.GpuDevice.GpuImage,
light_grid: gpu.GpuDevice.GpuBuffer,
light_index_list: gpu.GpuDevice.GpuBuffer,

pub fn init(renderer: *Renderer, size: [2]u32, id: u64, camera: ecs.Entity) !RenderView {
    // Zero-sized RenderViews are not allowed by the GPU.
    if (size[0] == 0 or size[1] == 0) return error.InvalidSize;

    const gpu_device = renderer.gpu_device;
    const num_tiles = ((size[0] + tile_size - 1) / tile_size) * ((size[1] + tile_size - 1) / tile_size);

    return .{
        .id = id,
        .size = size,
        .camera = camera,
        .renderer = renderer,
        .target = try gpu_device.createImage(.{
            .name = "RenderView target",
            .is_render_target = true,
            .width = size[0],
            .height = size[1],
            .format = .bgra8,
        }),
        .depth = try gpu_device.createImage(.{
            .name = "Depth buffer",
            .width = size[0],
            .height = size[1],
            .format = .d32
        }),
        .light_grid = try gpu_device.createBuffer(.{
            .name = "Light grid",
            .type = .storage,
            .usage = .default,
            .size = num_tiles * @sizeOf([2]u32),
            .stride = @sizeOf([2]u32)
        }),
        .light_index_list = try gpu_device.createBuffer(.{
            .name = "Light index list",
            .type = .storage,
            .usage = .default,
            .size = num_tiles * max_lights_per_tile * @sizeOf(u32),
            .stride = @sizeOf(u32)
        }),
    };
}

pub fn deinit(self: *RenderView) void {
    self.target.deinit();
    self.depth.deinit();
    self.light_grid.deinit();
    self.light_index_list.deinit();
}

pub fn resize(self: *RenderView, size: [2]u32) !void {
    if (size[0] == 0 or size[1] == 0) return;
    if (std.mem.eql(u32, &self.size, &size)) return;
    self.size = size;

    const gpu_device = self.renderer.gpu_device;
    const num_tiles = ((size[0] + tile_size - 1) / tile_size) * ((size[1] + tile_size - 1) / tile_size);

    const old_target = self.target;
    const old_depth = self.depth;
    const old_light_grid = self.light_grid;
    const old_light_index_List = self.light_index_list;
    defer {
        old_target.deinit();
        old_depth.deinit();
        old_light_grid.deinit();
        old_light_index_List.deinit();
    }

    self.target = try gpu_device.createImage(.{
        .name = "RenderView target",
        .is_render_target = true,
        .width = size[0],
        .height = size[1],
        .format = .bgra8
    });
    self.depth = try gpu_device.createImage(.{
        .name = "Depth buffer",
        .width = size[0],
        .height = size[1],
        .format = .d32
    });
    self.light_grid = try gpu_device.createBuffer(.{
        .name = "Light grid",
        .type = .storage,
        .usage = .default,
        .size = num_tiles * @sizeOf([2]u32),
        .stride = @sizeOf([2]u32)
    });
    self.light_index_list = try gpu_device.createBuffer(.{
        .name = "Light index list",
        .type = .storage,
        .usage = .default,
        .size = num_tiles * max_lights_per_tile * @sizeOf(u32),
        .stride = @sizeOf(u32)
    });
}
