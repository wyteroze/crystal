// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const sokol = @import("sokol");
const desc = @import("../desc.zig");
const types = @import("../types.zig");
const gfx = sokol.gfx;

const header_size = @sizeOf(usize);

const SokolBackend = @This();
allocator: std.mem.Allocator,

pub fn init(self: *const SokolBackend) void {
    gfx.setup(.{
        .logger = .{ .func = sokol.log.func },
        .allocator = .{ .alloc_fn = sokolAlloc, .free_fn = sokolFree, .user_data = @constCast(self) },
    });
}

pub fn deinit(self: SokolBackend) void {
    _ = self;
    gfx.shutdown();
}

pub fn createBuffer(self: SokolBackend, d: desc.BufferDesc) types.BufferHandle {
    _ = self;
    const buf = gfx.makeBuffer(.{ .size = d.size, .usage = switch (d.type) {
        .vertex => .{ .vertex_buffer = true },
        .index => .{ .index_buffer = true },
    }, .data = if (d.data) |data| gfx.asRange(data) else .{} });

    return .{ .id = buf.id };
}

pub fn createPipeline(self: SokolBackend, d: desc.PipelineDesc) types.PipelineHandle {
    _ = self;
    var layout: gfx.VertexLayoutState = .{};
    for (d.layout, 0..) |attr, i| {
        layout.attrs[i] = .{ .offset = attr.offset, .format = switch (attr.format) {
            .float2 => .FLOAT2,
            .float3 => .FLOAT3,
            .float4 => .FLOAT4,
            .ubyte4_norm => .UBYTE4N,
        } };
    }

    layout.buffers[0].stride = 32;

    const pipeline = gfx.makePipeline(.{
        .cull_mode = switch (d.cull_mode) {
            .front => .FRONT,
            .back => .BACK,
            .none => .NONE,
        },
        .index_type = switch (d.index_type) {
            .none => .NONE,
            .uint16 => .UINT16,
            .uint32 => .UINT32,
        },
        .depth = .{ .write_enabled = d.depth_write, .compare = .LESS_EQUAL },
        .shader = .{ .id = d.shader.id },
        .layout = layout,
    });

    return .{ .id = pipeline.id };
}

pub fn createShader(self: SokolBackend, d: gfx.ShaderDesc) types.ShaderHandle {
    _ = self;
    const shader = gfx.makeShader(d);
    return .{ .id = shader.id };
}

pub fn beginPass(self: SokolBackend, d: desc.PassDesc) void {
    _ = self;
    var pass = gfx.Pass{};

    pass.swapchain.width = @intCast(d.width);
    pass.swapchain.height = @intCast(d.height);
    pass.action.depth = .{ .load_action = .CLEAR, .clear_value = 1.0 };
    
    if (d.clear_color) |c| {
        pass.action.colors[0] = .{ .load_action = .CLEAR, .clear_value = .{ .r = c[0], .g = c[1], .b = c[2], .a = c[3] } };
    }

    gfx.beginPass(pass);
}

pub fn applyPipeline(self: SokolBackend, h: types.PipelineHandle) void {
    _ = self;
    gfx.applyPipeline(.{ .id = h.id });
}

pub fn applyBindings(self: SokolBackend, binds: desc.Bindings) void {
    _ = self;
    var bindings: gfx.Bindings = .{};

    for (binds.vertex_buffers, 0..) |b, i| {
        if (b) |buf| bindings.vertex_buffers[i] = .{ .id = buf.id };
    }

    if (binds.index_buffer) |buf| bindings.index_buffer = .{ .id = buf.id };

    for (binds.images, 0..) |image, i| {
        if (image) |img| bindings.views[i] = .{ .id = img.id };
    }

    gfx.applyBindings(bindings);
}

pub fn applyUniforms(self: SokolBackend, unis: desc.Uniforms) void {
    _ = self;
    gfx.applyUniforms(unis.slot, gfx.asRange(unis.data));
}

pub fn draw(self: SokolBackend, base: u32, count: u32, instances: u32) void {
    _ = self;
    gfx.draw(base, count, instances);
}

pub fn endPass(self: SokolBackend) void {
    _ = self;
    gfx.endPass();
}

pub fn commit(self: SokolBackend) void {
    _ = self;
    gfx.commit();
}

fn sokolAlloc(size: usize, user_data: ?*anyopaque) callconv(.c) ?*anyopaque {
    const backend: *SokolBackend = @ptrCast(@alignCast(user_data.?));

    const mem = backend.allocator.alignedAlloc(u8, .fromByteUnits(@alignOf(usize)), size + header_size) catch return null;
    
    const size_ptr: *usize = @ptrCast(@alignCast(mem.ptr));
    size_ptr.* = size;

    return mem.ptr + header_size;
}

fn sokolFree(ptr: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) void {
    const backend: *SokolBackend = @ptrCast(@alignCast(user_data.?));

    if (ptr) |p| {
        const base: [*]align(@alignOf(usize)) u8 = @ptrCast(@alignCast(@as([*]u8, @ptrCast(p)) - header_size));

        const size_ptr: *usize = @ptrCast(base);
        const size = size_ptr.*;

        backend.allocator.free(base[0 .. size + header_size]);
    }
}