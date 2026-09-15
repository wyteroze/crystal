// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const pass = @import("pass.zig");
const types = @import("../types.zig");
const gpu = @import("../../gpu/gpu.zig");
const core = @import("../../core/core.zig");
const resource = @import("../resource.zig");
const math = core.math;

const ForwardPass = @This();
pipeline: gpu.GpuDevice.GpuPipeline,
vs_ubuf: gpu.GpuDevice.GpuBuffer,
light_ubuf: gpu.GpuDevice.GpuBuffer,
clear_color: core.Color,

pub fn init(gpu_device: *gpu.GpuDevice, shader: gpu.GpuDevice.GpuShader, clear_color: core.Color) !ForwardPass {
    return .{
        .pipeline = try gpu_device.createPipeline(.{
            .name = "Forward pass pipeline",
            .shader = shader.handle,
            .index_type = .uint32,
            .cull_mode = .none,
            .depth_write = true,
            .resources = &.{
                .{ .name = "vsParams", .kind = .uniform_buffer, .visibility = .vertex_fragment },
                .{ .name = "texture", .kind = .texture, .visibility = .vertex_fragment },
                .{ .name = "sampler", .kind = .sampler, .visibility = .vertex_fragment },
                .{ .name = "lightParams", .kind = .uniform_buffer, .visibility = .vertex_fragment },
                .{ .name = "lights", .kind = .storage_buffer, .visibility = .fragment },
                .{ .name = "lightGrid", .kind = .storage_buffer, .visibility = .fragment },
                .{ .name = "lightIndexList", .kind = .storage_buffer, .visibility = .fragment },
            },
            .layout = &.{
                .{ .offset = 0, .format = .float3 },
                .{ .offset = 12, .format = .float3 },
                .{ .offset = 24, .format = .float2 },
            },
        }),
        .vs_ubuf = try gpu_device.createBuffer(.{ 
            .name = "Vs ubuf", 
            .type = .uniform, 
            .usage = .dynamic, 
            .size = @sizeOf([3]math.Mat4) 
        }),
        .light_ubuf = try gpu_device.createBuffer(.{ 
            .name = "Light ubuf", 
            .type = .uniform, 
            .usage = .dynamic, 
            .size = @sizeOf(gpu.types.GpuLightParams) 
        }),
        .clear_color = clear_color
    };
}

pub fn execute(self: *ForwardPass, ctx: pass.PassContext) void {
    const depth_handle = ctx.resources.get(resource.depth_buffer, .image) orelse @panic("depth_buffer resource missing!");
    ctx.device.beginPass(.{
        .width = ctx.view.viewport_size[0],
        .height = ctx.view.viewport_size[1],
        .depth_target = depth_handle
    });
    self.pipeline.apply();

    const lights_handle = ctx.resources.get(resource.lights_buffer, .storage_buffer) orelse @panic("lights_buffer resource missing!");
    const light_grid_handle = ctx.resources.get(resource.light_grid, .storage_buffer) orelse @panic("light_grid resource missing!");
    const light_index_list_handle = ctx.resources.get(resource.light_index_list, .storage_buffer) orelse @panic("light_index_list resource missing!");

    const tile_count: [2]u32 = .{
        (ctx.view.viewport_size[0] + 15) / 16,
        (ctx.view.viewport_size[1] + 15) / 16
    };
    const light_params = gpu.types.GpuLightParams{
        .ambient = .{ 0.1, 0.1, 0.1 },
        .screen_size = ctx.view.viewport_size,
        .tile_count = tile_count
    };
    self.light_ubuf.update(std.mem.asBytes(&light_params));

    for (ctx.scene.objects.items) |obj| {
        const vs_params: [3][4][4]f32 = .{
            @bitCast(obj.model),
            @bitCast(ctx.view.view_matrix),
            @bitCast(ctx.view.proj_matrix),
        };
        self.vs_ubuf.update(std.mem.asBytes(&vs_params));

        self.pipeline.applyBindings(.{
            .vertex_buffers = .{ obj.mesh.vertex_buffer.handle, null, null, null },
            .index_buffer = obj.mesh.index_buffer.handle,
            .resources = &.{
                .{ .name = "vsParams", .handle = .{ .uniform_buffer = self.vs_ubuf.handle } },
                .{ .name = "texture", .handle = .{ .texture = obj.material.image.handle } },
                .{ .name = "sampler", .handle = .{ .sampler = obj.material.sampler.handle } },
                .{ .name = "lightParams", .handle = .{ .uniform_buffer = self.light_ubuf.handle } },
                .{ .name = "lights", .handle = .{ .storage_buffer = lights_handle } },
                .{ .name = "lightGrid", .handle = .{ .storage_buffer = light_grid_handle } },
                .{ .name = "lightIndexList", .handle = .{ .storage_buffer = light_index_list_handle } }
            }
        });

        self.pipeline.draw(0, obj.mesh.index_count, 1);
    }

    ctx.device.endPass();
}

pub fn deinit(self: *ForwardPass, allocator: std.mem.Allocator) void {
    self.pipeline.deinit();
    self.vs_ubuf.deinit();
    self.light_ubuf.deinit();
    allocator.destroy(self);
}

pub fn node(self: *ForwardPass) pass.PassNode {
    return .{
        .name = "ForwardPass",
        .reads = &.{ resource.depth_buffer, resource.lights_buffer, resource.light_grid, resource.light_index_list },
        .writes = &.{ resource.color_target },
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
        }.c,
    };
}