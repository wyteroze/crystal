// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const pass = @import("pass.zig");
const gpu = @import("../../gpu/gpu.zig");
const core = @import("../../core/core.zig");
const resource = @import("../resource.zig");
const Renderer = @import("../Renderer.zig");
const math = core.math;

const tile_size = Renderer.tile_size;

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

pub fn init(gpu_device: *gpu.GpuDevice, shader: gpu.GpuDevice.GpuShader) !LightCullPass {
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
    };
}

pub fn execute(self: *LightCullPass, ctx: pass.PassContext) void {
    const depth_tex = ctx.resources.get(resource.depth_texture, .image) orelse @panic("depth_texture missing!");
    const lights_handle = ctx.resources.get(resource.lights_buffer, .storage_buffer) orelse @panic("lights_buffer missing!");
    const grid = ctx.resources.get(resource.light_grid, .storage_buffer) orelse @panic("light_grid missing!");
    const index_list = ctx.resources.get(resource.light_index_list, .storage_buffer) orelse @panic("light_index_list missing!");

    const tile_count: [2]u32 = .{
        (ctx.view.viewport_size[0] + tile_size - 1) / tile_size,
        (ctx.view.viewport_size[1] + tile_size - 1) / tile_size,
    };

    const cull_params: CullParams = .{
        .inv_proj = ctx.view.proj_matrix.invertPerspectiveReversedZInf().m,
        .view = ctx.view.view_matrix.m,
        .screen_size = ctx.view.viewport_size,
        .tile_count = tile_count,
        .light_count = @intCast(ctx.scene.lights.len)
    };
    self.cull_ubuf.update(std.mem.asBytes(&cull_params));

    self.compute_pipeline.apply();
    self.compute_pipeline.applyBindings(.{
        .resources = &.{
            .{ .name = "cullParams", .handle = .{ .uniform_buffer = self.cull_ubuf.handle } },
            .{ .name = "depthTexture", .handle = .{ .texture = depth_tex } },
            .{ .name = "lights", .handle = .{ .storage_buffer = lights_handle } },
            .{ .name = "lightGrid", .handle = .{ .storage_buffer_rw = grid } },
            .{ .name = "lightIndexList", .handle = .{ .storage_buffer_rw = index_list } },
        }
    });
    self.compute_pipeline.dispatch(tile_count[0], tile_count[1], 1);
}

pub fn deinit(self: *LightCullPass, allocator: std.mem.Allocator) void {
    self.compute_pipeline.deinit();
    self.cull_ubuf.deinit();
    allocator.destroy(self);
}

pub fn node(self: *LightCullPass) pass.PassNode {
    return .{
        .name = "LightCullPass",
        .reads = &.{ resource.depth_buffer, resource.depth_texture, resource.lights_buffer },
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
