// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const pass = @import("pass.zig");
const gpu = @import("../../gpu/gpu.zig");
const core = @import("../../core/core.zig");
const resource = @import("../resource.zig");
const math = core.math;

const tile_size = 16;
const max_lights_per_tile = 256;

const CullParams = extern struct {
    inv_proj: [4][4]f32,
    view: [4][4]f32,
    screen_size: [2]u32,
    tile_count: [2]u32,
    light_count: u32,
    _pad: [3]u32 = undefined
};

const LightCullPass = @This();
compute_pipeline: gpu.GpuDevice.GpuComputePipeline,
cull_ubuf: gpu.GpuDevice.GpuBuffer,
light_grid: gpu.GpuDevice.GpuBuffer,
light_index_list: gpu.GpuDevice.GpuBuffer,
tile_count: [2]u32,

pub fn init(gpu_device: *gpu.GpuDevice, shader: gpu.GpuDevice.GpuShader, surface_size: [2]u32) !LightCullPass {
    const tile_count = calculateTileCount(surface_size);
    const num_tiles = tile_count[0] * tile_count[1];

    return .{
        .compute_pipeline = try gpu_device.createComputePipeline(.{
            .name = "Light cull pipeline",
            .shader = shader.handle,
            .resources = &.{
                .{ .name = "cullParams", .kind = .uniform_buffer, .visibility = .compute },
                .{ .name = "depthTexture", .kind = .texture, .visibility = .compute },
                .{ .name = "lights", .kind = .storage_buffer, .visibility = .compute },
                .{ .name = "lightGrid", .kind = .storage_buffer_rw, .visibility = .compute },
                .{ .name = "lightIndexList", .kind = .storage_buffer_rw, .visibility = .compute }
            }
        }),
        .cull_ubuf = try gpu_device.createBuffer(.{
            .name = "Light cull params ubuf",
            .type = .uniform,
            .usage = .dynamic,
            .size = @sizeOf(CullParams)
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
        .tile_count = tile_count
    };
}

pub fn execute(self: *LightCullPass, ctx: pass.PassContext) void {
    const depth_handle = ctx.resources.get(resource.depth_buffer, .image) orelse @panic("depth_buffer resource is missing!");
    const lights_handle = ctx.resources.get(resource.lights_buffer, .storage_buffer) orelse @panic("lights_buffer resource is missing!");

    const cull_params: CullParams = .{
        .inv_proj = @bitCast(ctx.view.proj_matrix.invertPerspective()),
        .view = @bitCast(ctx.view.view_matrix),
        .screen_size = ctx.view.viewport_size,
        .tile_count = self.tile_count,
        .light_count = @intCast(ctx.scene.lights.items.len)
    };
    self.cull_ubuf.update(std.mem.asBytes(&cull_params));

    self.compute_pipeline.apply();
    self.compute_pipeline.applyBindings(.{
        .resources = &.{
            .{ .name = "cullParams", .handle = .{ .uniform_buffer = self.cull_ubuf.handle } },
            .{ .name = "depthTexture", .handle = .{ .texture = depth_handle } },
            .{ .name = "lights", .handle = .{ .storage_buffer = lights_handle } },
            .{ .name = "lightGrid", .handle = .{ .storage_buffer_rw = self.light_grid.handle } },
            .{ .name = "lightIndexList", .handle = .{ .storage_buffer_rw = self.light_index_list.handle } }
        }
    });

    self.compute_pipeline.dispatch(self.tile_count[0], self.tile_count[1], 1);

    ctx.resources.put(resource.light_grid, .{ .storage_buffer = self.light_grid.handle }) catch @panic("Out of memory");
    ctx.resources.put(resource.light_index_list, .{ .storage_buffer = self.light_index_list.handle }) catch @panic("Out of memory");
}

pub fn deinit(self: *LightCullPass, allocator: std.mem.Allocator) void {
    self.compute_pipeline.deinit();
    self.cull_ubuf.deinit();
    self.light_grid.deinit();
    self.light_index_list.deinit();
    allocator.destroy(self);
}

pub fn node(self: *LightCullPass) pass.PassNode {
    return .{
        .name = "LightCullPass",
        .reads = &.{ resource.depth_buffer, resource.lights_buffer },
        .writes = &.{ resource.light_grid, resource.light_index_list },
        .ptr = self,
        .execute_fn = struct {
            fn c(ptr: *anyopaque, ctx: pass.PassContext) void {
                execute(@ptrCast(@alignCast(ptr)), ctx);
            }
        }.c,
        .deinit_fn = struct {
            fn c(ptr: *anyopaque, allocator: std.mem.Allocator) void {
                deinit(@ptrCast(@alignCast(ptr)), allocator);
            }
        }.c
    };
}

fn calculateTileCount(surface_size: [2]u32) [2]u32 {
    return .{
        (surface_size[0] + tile_size - 1) / tile_size,
        (surface_size[1] + tile_size - 1) / tile_size
    };
}