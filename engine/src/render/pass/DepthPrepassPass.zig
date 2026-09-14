// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const core = @import("../../core/core.zig");
const math = core.math;
const pass = @import("pass.zig");
const gpu = @import("../../gpu/gpu.zig");
const resource = @import("../resource.zig");

const DepthPrepassPass = @This();
pipeline: gpu.GpuDevice.GpuPipeline,
vs_ubuf: gpu.GpuDevice.GpuBuffer,

pub fn init(gpu_device: *gpu.GpuDevice, shader: gpu.GpuDevice.GpuShader) !DepthPrepassPass {
    return .{
        .pipeline = try gpu_device.createPipeline(.{
            .name = "Depth prepass pipeline",
            .shader = shader.handle,
            .index_type = .uint32,
            .cull_mode = .none,
            .depth_write = true,
            .color_write_mask = .none(),
            .resources = &.{
                .{ .name = "VSParams", .kind = .uniform_buffer, .visibility = .vertex }
            },
            .layout = &.{
                .{ .offset = 0, .format = .float3 },
                .{ .offset = 12, .format = .float3 },
                .{ .offset = 24, .format = .float2 }
            }
        }),
        .vs_ubuf = try gpu_device.createBuffer(.{
            .name = "Depth prepass vs ubuf",
            .type = .uniform,
            .usage = .dynamic,
            .size = @sizeOf([3]math.Mat4)
        })
    };
}

pub fn execute(self: *DepthPrepassPass, ctx: pass.PassContext) void {
    const depth_handle = ctx.resources.get(resource.depth_buffer, .image) orelse @panic("depth_buffer resource is missing!");
    ctx.device.beginPass(.{
        .clear_depth = 1.0,
        .width = ctx.view.viewport_size[0],
        .height = ctx.view.viewport_size[1],
        .depth_target = depth_handle
    });
    self.pipeline.apply();

    for (ctx.scene.objects.items) |obj| {
        const vs_params: [3][4][4]f32 = .{
            @bitCast(obj.model),
            @bitCast(ctx.view.view_matrix),
            @bitCast(ctx.view.proj_matrix)
        };
        self.vs_ubuf.update(std.mem.asBytes(&vs_params));

        self.pipeline.applyBindings(.{
            .vertex_buffers = .{ obj.mesh.vertex_buffer.handle, null, null, null },
            .index_buffer = obj.mesh.index_buffer.handle,
            .resources = &.{
                .{ .name = "VSParams", .handle = .{ .uniform_buffer = self.vs_ubuf.handle } }
            }
        });

        self.pipeline.draw(0, obj.mesh.index_count, 1);
    }

    ctx.device.endPass();
}

pub fn deinit(self: *DepthPrepassPass, allocator: std.mem.Allocator) void {
    self.pipeline.deinit();
    self.vs_ubuf.deinit();
    allocator.destroy(self);
}

pub fn node(self: *DepthPrepassPass) pass.PassNode {
    return .{
        .name = "DepthPrepassPass",
        .reads = &.{},
        .writes = &.{ resource.depth_buffer },
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