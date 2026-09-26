// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../../gpu/gpu.zig");
const RenderGraph = @import("../RenderGraph.zig");
const resource = @import("../resource.zig");
const pass = @import("pass.zig");
const core = @import("../../core/core.zig");
const Assets = @import("../../assets/Assets.zig");
const text = @import("../text/text.zig");
const math = core.math;

const GpuUiParams = extern struct {
    ortho: [4][4]f32,
    pos: [2]f32,
    size: [2]f32,
    color: [4]f32,
    uv_pos: [2]f32,
    uv_size: [2]f32,
    is_text: u32,
};

const UiPass = @This();
pipeline: gpu.GpuDevice.GpuPipeline,
shader: gpu.GpuDevice.GpuShader,
sampler: gpu.GpuDevice.GpuSampler,
vs_ubuf: gpu.GpuDevice.GpuBuffer,
ui_quad: Assets.types.GpuMesh,
ortho_matrix: math.Mat4,
surface_pixel_size: [2]u32,
surface_scale: f32,

pub fn init(device: *gpu.GpuDevice, shader: gpu.GpuDevice.GpuShader, surface_pixel_size: [2]u32, surface_scale: f32) !UiPass {
    const pipeline = try device.createPipeline(.{
        .name = "Ui pipeline",
        .shader = shader.handle,
        .cull_mode = .none,
        .depth_write = false,
        .alpha_blend_enabled = true,
        .layout = &.{
            .{ .offset = 0, .format = .float3 },
            .{ .offset = 12, .format = .float3 },
            .{ .offset = 24, .format = .float2 }
        },
        .resources = &.{
            .{ .name = "vsParams", .visibility = .vertex_fragment, .kind = .uniform_buffer },
            .{ .name = "atlasTexture", .visibility = .fragment, .kind = .texture },
            .{ .name = "atlasSampler", .visibility = .fragment, .kind = .sampler }
        },
        .index_type = .uint32
    });

    return .{
        .pipeline = pipeline,
        .shader = shader,
        .sampler = try device.createSampler(.{}),
        .surface_pixel_size = surface_pixel_size,
        .surface_scale = surface_scale,
        .vs_ubuf = try device.createBuffer(.{ 
            .name = "Vs ubuf", 
            .type = .uniform, 
            .usage = .dynamic, 
            .size = @sizeOf(GpuUiParams)
        }),
        .ui_quad = .{
            .vertex_buffer = try device.createBuffer(.{
                .name = "Ui quad vertex buffer",
                .data = std.mem.sliceAsBytes(([_]Assets.types.Vertex{
                    .{ .position = .{  0.0,  0.0,  0.0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 0, 0 } },
                    .{ .position = .{  1.0,  0.0,  0.0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 1, 0 } },
                    .{ .position = .{  0.0,  1.0,  0.0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 0, 1 } },
                    .{ .position = .{  1.0,  1.0,  0.0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 1, 1 } },
                })[0..]),
                .size = 4,
            }),
            .index_buffer = try device.createBuffer(.{
                .name = "Ui quad index buffer",
                .type = .index,
                .data = std.mem.sliceAsBytes(([_]u32{
                    0, 2, 1,
                    1, 2, 3
                })[0..])
            }),
            .vertex_count = 4,
            .index_count = 6
        },
        .ortho_matrix = .ortho(0, @floatFromInt(surface_pixel_size[0]), @floatFromInt(surface_pixel_size[1]), 0.0, -1.0, 1.0)
    };
}

pub fn deinit(self: *UiPass, allocator: std.mem.Allocator) void {
    self.pipeline.deinit();
    self.shader.deinit();
    self.sampler.deinit();
    allocator.destroy(self);
}

fn execute(self: *UiPass, ctx: pass.PassContext) void {
    ctx.device.beginPass(.{
        .width = ctx.view.viewport_size[0],
        .height = ctx.view.viewport_size[1]
    });
    self.pipeline.apply();

    const default_image_handle = ctx.resources.get(resource.default_image, .image) orelse @panic("default_image resource missing!");
    const default_sampler_handle = ctx.resources.get(resource.default_sampler, .sampler) orelse @panic("default_sampler resource missing!");

    for (ctx.scene.ui_objects) |ui_obj| {
        const vs_params: GpuUiParams = .{
            .ortho = self.ortho_matrix.m,
            .pos = .{ ui_obj.pos[0] * self.surface_scale, ui_obj.pos[1] * self.surface_scale },
            .size = .{ ui_obj.size[0] * self.surface_scale, ui_obj.size[1] * self.surface_scale },
            .color = ui_obj.color.data,
            .uv_pos = ui_obj.uv_pos,
            .uv_size = ui_obj.uv_size,
            .is_text = @intCast(@intFromBool(ui_obj.is_text))
        };

        self.vs_ubuf.update(std.mem.asBytes(&vs_params));

        const texture_handle = ui_obj.texture orelse default_image_handle;
        const sampler_handle = ui_obj.sampler orelse default_sampler_handle;

        self.pipeline.applyBindings(.{
            .vertex_buffers = .{ self.ui_quad.vertex_buffer.handle, null, null, null },
            .index_buffer = self.ui_quad.index_buffer.handle,
            .resources = &.{
                .{ .name = "vsParams", .handle = .{ .uniform_buffer = self.vs_ubuf.handle } },
                .{ .name = "atlasTexture", .handle = .{ .texture = texture_handle } },
                .{ .name = "atlasSampler", .handle = .{ .sampler = sampler_handle } }
            }
        });
        self.pipeline.draw(0, self.ui_quad.index_count, 1);
    }

    ctx.device.endPass();
}

pub fn node(self: *UiPass) pass.PassNode {
    return .{
        .name = "UiPass",
        .reads = &.{ resource.default_sampler, resource.default_image },
        .writes = &.{},
        .after = &.{ },
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