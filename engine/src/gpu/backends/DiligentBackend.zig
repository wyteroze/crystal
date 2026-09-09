// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const desc = @import("../desc.zig");
const types = @import("../types.zig");
const c = @import("diligent");

const DiligentBackend = @This();
handle: c.CrystalDiligentDeviceHandle = undefined,

pub fn init(surface_handle: ?*anyopaque, surface_size: [2]u32) DiligentBackend {
    return .{
        .handle = c.diligent_init(surface_handle, surface_size[0], surface_size[1])
    };
}

pub fn deinit(self: DiligentBackend) void {
    c.diligent_deinit(self.handle);
}

pub fn createBuffer(self: DiligentBackend, d: desc.BufferDesc) types.BufferHandle { 
    const buf_h = c.diligent_create_buffer(self.handle, .{
        .name = d.name.ptr,
        .type = @intFromEnum(d.type),
        .usage = @intFromEnum(d.usage),
        .size = if (d.data) |data| data.len else 0,
        .data = if (d.data) |data| data.ptr else @ptrFromInt(0)
    });

    return .{ .ptr = buf_h.ptr }; 
}

pub fn updateBuffer(self: DiligentBackend, h: types.BufferHandle, data: []const u8) void {
    c.diligent_update_buffer(self.handle, .{ .ptr = h.ptr }, data.ptr, data.len);
}

pub fn createSampler(self: DiligentBackend, d: desc.SamplerDesc) types.SamplerHandle { 
    const sam_h = c.diligent_create_sampler(self.handle, .{
        .wrap_u = @intFromEnum(d.wrap_u),
        .wrap_v = @intFromEnum(d.wrap_v),
        .min_filter = @intFromEnum(d.min_filter),
        .mag_filter = @intFromEnum(d.mag_filter),
        .mip_filter = @intFromEnum(d.mip_filter)
    });

    return .{ .ptr = sam_h.ptr }; 
}

pub fn createImage(self: DiligentBackend, d: desc.ImageDesc) types.ImageHandle {
    const img_h = c.diligent_create_image(self.handle, .{
        .name = d.name,
        .width = d.width,
        .height = d.height,
        .format = @intFromEnum(d.format),
        .data = d.data.?.ptr
    });

    return .{ .ptr = img_h.ptr }; 
}

pub fn createPipeline(self: DiligentBackend, d: desc.PipelineDesc) types.PipelineHandle { 
    const pipe_h = c.diligent_create_pipeline(self.handle, .{
        .name = d.name,
        .shader = .{ .ptr = d.shader.ptr },
        .depth_write = d.depth_write,
        .index_type = @intFromEnum(d.index_type),
        .cull_mode = @intFromEnum(d.cull_mode),
        .layout = @ptrCast(d.layout.ptr),
        .layout_len = d.layout.len
    });

    return .{ .ptr = pipe_h.ptr }; 
}

pub fn createShader(self: DiligentBackend, d: desc.ShaderDesc) types.ShaderHandle {
    // might need to bump this up in the future
    var stages: [8]c.CrystalShaderStageDesc = undefined;
    for (d.stages, 0..) |stage, i| {
        stages[i] = .{
            .stage = @intFromEnum(stage.stage),
            .source = stage.source.ptr,
            .entrypoint = stage.entrypoint.ptr
        };
    }

    const shd_h = c.diligent_create_shader(self.handle, .{
        .stages = &stages,
        .stages_len = d.stages.len
    });

    return .{ .ptr = shd_h.ptr };
}

pub fn beginPass(self: DiligentBackend, d: desc.PassDesc) void {
    c.diligent_begin_pass(self.handle, .{
        .width = d.width,
        .height = d.height,
        .clear_color = if (d.clear_color) |cc| cc.data else undefined,
        .has_clear_color = d.clear_color != null,
        .clear_depth = d.clear_depth orelse undefined,
        .has_clear_depth = d.clear_depth != null
    });
}

pub fn applyPipeline(self: DiligentBackend, h: types.PipelineHandle) void {
    c.diligent_apply_pipeline(self.handle, .{ .ptr = h.ptr });
}

pub fn drawPipeline(self: DiligentBackend, h: types.PipelineHandle, base: u32, count: u32, instances: u32) void {
    c.diligent_draw_pipeline(self.handle, .{ .ptr = h.ptr }, base, count, instances);
}

pub fn applyPipelineBindings(self: DiligentBackend, h: types.PipelineHandle, d: desc.Bindings) void {
    var vertex_buffers: [4]c.CrystalBufferHandle = undefined;
    for (d.vertex_buffers, 0..) |vb, i| {
        vertex_buffers[i] = .{ .ptr = if (vb) |handle| handle.ptr else null };
    }

    var uniform_buffers: [4]c.CrystalBufferHandle = undefined;
    for (d.uniform_buffers, 0..) |ub, i| {
        uniform_buffers[i] = .{ .ptr = if (ub) |handle| handle.ptr else null };
    }

    var images: [4]c.CrystalImageHandle = undefined;
    for (d.images, 0..) |img, i| {
        images[i] = .{ .ptr = if (img) |handle| handle.ptr else null };
    }

    var samplers: [4]c.CrystalSamplerHandle = undefined;
    for (d.samplers, 0..) |smp, i| {
        samplers[i] = .{ .ptr = if (smp) |handle| handle.ptr else null };
    }

    c.diligent_pipeline_apply_bindings(self.handle, .{ .ptr = h.ptr }, .{
        .vertex_buffers = vertex_buffers,
        .index_buffer = .{ .ptr = if (d.index_buffer) |handle| handle.ptr else null },
        .uniform_buffers = uniform_buffers,
        .images = images,
        .samplers = samplers
    });
}

pub fn endPass(self: DiligentBackend) void { c.diligent_end_pass(self.handle); }

pub fn present(self: DiligentBackend) void {
    c.diligent_present(self.handle);
}