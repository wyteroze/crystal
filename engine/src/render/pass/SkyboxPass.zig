// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../../gpu/gpu.zig");
const RenderGraph = @import("../RenderGraph.zig");
const resource = @import("../resource.zig");
const pass = @import("pass.zig");
const core = @import("../../core/core.zig");
const math = core.math;

const SkyboxPass = @This();
pipeline: gpu.GpuDevice.GpuPipeline,
shader: gpu.GpuDevice.GpuShader,
sampler: gpu.GpuDevice.GpuSampler,
view_ubo: gpu.GpuDevice.GpuBuffer,
cubemap: gpu.GpuDevice.GpuImage,

pub fn init(device: *gpu.GpuDevice, shader: gpu.GpuDevice.GpuShader, cubemap: gpu.GpuDevice.GpuImage) !SkyboxPass {
    const pipeline = try device.createPipeline(.{
        .name = "Skybox pipeline",
        .shader = shader.handle,
        .cull_mode = .none,
        .depth_write = false,
        .layout = &.{},
        .resources = &.{
            .{ .name = "vsParams", .visibility = .vertex_fragment, .kind = .uniform_buffer },
            .{ .name = "skyboxTexture", .visibility = .fragment, .kind = .texture },
            .{ .name = "skyboxSampler", .visibility = .fragment, .kind = .sampler }
        },
        .index_type = .uint32
    });

    return .{
        .pipeline = pipeline,
        .shader = shader,
        .sampler = try device.createSampler(.{}),
        .view_ubo = try device.createBuffer(.{
            .name = "Skybox view uniforms",
            .type = .uniform,
            .usage = .dynamic,
            .size = @sizeOf(math.Mat4)
        }),
        .cubemap = cubemap
    };
}

pub fn deinit(self: *SkyboxPass, allocator: std.mem.Allocator) void {
    self.pipeline.deinit();
    self.sampler.deinit();
    self.view_ubo.deinit();
    allocator.destroy(self);
}

fn execute(self: *SkyboxPass, ctx: pass.PassContext) void {
    const depth_handle = ctx.resources.get(resource.depth_buffer, .image) orelse @panic("depth_buffer resource missing!");
    ctx.device.beginPass(.{
        .clear_color = .fromRgbFloat(0.1, 0.1, 0.1, 1.0),
        .clear_depth = 1.0,
        .width = ctx.view.viewport_size[0],
        .height = ctx.view.viewport_size[1],
        .depth_target = depth_handle
    });

    const inv_view = ctx.view.view_matrix.invertRT();
    const inv_proj = ctx.view.proj_matrix.invertPerspective();
    const inv_view_proj = inv_view.mul(inv_proj);
    self.view_ubo.update(std.mem.asBytes(&inv_view_proj));

    self.pipeline.apply();
    self.pipeline.applyBindings(.{
        .resources = &.{
            .{ .name = "vsParams", .handle = .{ .uniform_buffer = self.view_ubo.handle } },
            .{ .name = "skyboxTexture", .handle = .{ .texture = self.cubemap.handle } },
            .{ .name = "skyboxSampler", .handle = .{ .sampler = self.sampler.handle } }
        }
    });
    self.pipeline.draw(0, 3, 1);

    ctx.device.endPass();
}

pub fn node(self: *SkyboxPass) pass.PassNode {
    return .{
        .name = "SkyboxPass",
        .reads = &.{ resource.depth_buffer },
        .writes = &.{},
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