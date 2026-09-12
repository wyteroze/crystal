// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const desc = @import("../desc.zig");
const types = @import("../types.zig");
const c = @import("diligent");

fn buildResourceDescs(buf: []c.CrystalResourceDesc, resources: []const desc.ResourceDesc) []c.CrystalResourceDesc {
    for (resources, 0..) |r, i| {
        buf[i] = .{
            .name = r.name.ptr,
            .kind = @intFromEnum(r.kind),
            .visibility = @intFromEnum(r.visibility),
        };
    }

    return buf[0..resources.len];
}

fn buildBoundResources(buf: []c.CrystalBoundResource, resources: []const desc.BoundResource) []c.CrystalBoundResource {
    for (resources, 0..) |r, i| {
        const handle_ptr = switch (r.handle) { inline else => |h| h.ptr };

        buf[i] = .{
            .name = r.name.ptr,
            .kind = @intFromEnum(std.meta.activeTag(r.handle)),
            .handle_ptr = handle_ptr,
        };
    }

    return buf[0..resources.len];
}

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
        .stride = d.stride,
        .size = if (d.data) |data| data.len else d.size,
        .data = if (d.data) |data| data.ptr else @ptrFromInt(0),
    });

    return .{ .ptr = buf_h.ptr }; 
}

pub fn destroyBuffer(self: DiligentBackend, h: types.BufferHandle) void {
    c.diligent_destroy_buffer(self.handle, .{ .ptr = h.ptr });
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

pub fn destroyImage(self: DiligentBackend, h: types.ImageHandle) void {
    c.diligent_destroy_image(self.handle, .{ .ptr = h.ptr });
}

pub fn createPipeline(self: DiligentBackend, d: desc.PipelineDesc) types.PipelineHandle { 
    std.debug.assert(d.resources.len <= 16);
    var resource_buf: [16]c.CrystalResourceDesc = undefined;
    const resources = buildResourceDescs(&resource_buf, d.resources);

    const pipe_h = c.diligent_create_pipeline(self.handle, .{
        .name = d.name,
        .shader = .{ .ptr = d.shader.ptr },
        .depth_write = d.depth_write,
        .index_type = @intFromEnum(d.index_type),
        .cull_mode = @intFromEnum(d.cull_mode),
        .layout = @ptrCast(d.layout.ptr),
        .layout_len = d.layout.len,
        .resources = resources.ptr,
        .resources_len = resources.len
    });

    return .{ .ptr = pipe_h.ptr }; 
}

pub fn createComputePipeline(self: DiligentBackend, d: desc.ComputePipelineDesc) types.ComputePipelineHandle {
    std.debug.assert(d.resources.len <= 16);
    var resource_buf: [16]c.CrystalResourceDesc = undefined;
    const resources = buildResourceDescs(&resource_buf, d.resources);

    const pipe_h = c.diligent_create_compute_pipeline(self.handle, .{
        .name = d.name,
        .shader = .{ .ptr = d.shader.ptr },
        .resources = resources.ptr,
        .resources_len = resources.len
    });

    return .{ .ptr = pipe_h.ptr };
}

pub fn destroyComputePipeline(self: DiligentBackend, h: types.ComputePipelineHandle) void {
    c.diligent_destroy_compute_pipeline(self.handle, .{ .ptr = h.ptr });
}

pub fn applyComputePipeline(self: DiligentBackend, h: types.ComputePipelineHandle) void {
    c.diligent_apply_compute_pipeline(self.handle, .{ .ptr = h.ptr });
}

pub fn dispatchCompute(self: DiligentBackend, h: types.ComputePipelineHandle, groups_x: u32, groups_y: u32, groups_z: u32) void {
    c.diligent_dispatch_compute(self.handle, .{ .ptr = h.ptr }, groups_x, groups_y, groups_z);
}

pub fn createShader(self: DiligentBackend, d: desc.ShaderDesc) types.ShaderHandle {
    // might need to bump this up in the future
    std.debug.assert(d.stages.len <= 8);
    var stages: [8]c.CrystalShaderStageDesc = undefined;
    for (d.stages, 0..) |stage, i| {
        stages[i] = .{
            .name = stage.name,
            .stage = @intFromEnum(stage.stage),
            .source = stage.source.ptr,
            .source_len = @intCast(stage.source.len),
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
        vertex_buffers[i] = .{ .ptr = if (vb) |handle| handle.ptr else @ptrFromInt(0) };
    }

    std.debug.assert(d.resources.len <= 16);
    var resource_buf: [16]c.CrystalBoundResource = undefined;
    const resources = buildBoundResources(&resource_buf, d.resources);

    c.diligent_pipeline_apply_bindings(self.handle, .{ .ptr = h.ptr }, .{
        .vertex_buffers = vertex_buffers,
        .index_buffer = .{ .ptr = if (d.index_buffer) |handle| handle.ptr else @ptrFromInt(0) },
        .resources = resources.ptr,
        .resources_len = resources.len
    });
}

pub fn applyComputeBindings(self: DiligentBackend, h: types.ComputePipelineHandle, d: desc.Bindings) void {
    std.debug.assert(d.resources.len <= 16);
    var resource_buf: [16]c.CrystalBoundResource = undefined;
    const resources = buildBoundResources(&resource_buf, d.resources);

    c.diligent_apply_compute_bindings(self.handle, .{ .ptr = h.ptr }, .{
        .vertex_buffers = @splat(.{ .ptr = @ptrFromInt(0) }),
        .index_buffer = .{ .ptr = @ptrFromInt(0) },
        .resources = resources.ptr,
        .resources_len = resources.len
    });
}

pub fn endPass(self: DiligentBackend) void { c.diligent_end_pass(self.handle); }

pub fn present(self: DiligentBackend) void {
    c.diligent_present(self.handle);
}

pub fn queryBackend(_: DiligentBackend) desc.Backend {
    return switch (c.diligent_query_backend()) {
        c.CRYSTAL_BACKEND_OPENGL => .opengl,
        c.CRYSTAL_BACKEND_DIRECT3D11 => .direct3d11,
        c.CRYSTAL_BACKEND_DIRECT3D12 => .direct3d12,
        c.CRYSTAL_BACKEND_VULKAN => .vulkan,
        else => unreachable
    };
}