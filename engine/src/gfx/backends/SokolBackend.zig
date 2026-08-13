// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const sokol = @import("sokol");
const desc = @import("../desc.zig");
const types = @import("../types.zig");
const gfx = sokol.gfx;

const SokolBackend = @This();

pub fn init(self: SokolBackend) void {
    _ = self;

    gfx.setup(.{
        .logger = .{ .func = sokol.log.func }
    });
}

pub fn deinit(self: SokolBackend) void {
    _ = self;
    gfx.shutdown();
}

pub fn createBuffer(self: SokolBackend, d: desc.BufferDesc) types.BufferHandle {
    _ = self;
    const buf = gfx.makeBuffer(.{
        .size = d.size,
        .usage = switch (d.type) { .vertex => .{ .vertex_buffer = true }, .index => .{ .index_buffer = true } },
        .data = if (d.data) |data| gfx.asRange(data) else .{}
    });

    return .{ .id = buf.id };
}

pub fn createPipeline(self: SokolBackend, d: desc.PipelineDesc) types.PipelineHandle {
    _ = self;
    var layout: gfx.VertexLayoutState = .{};
    for (d.layout, 0..) |attr, i| {
        layout.attrs[i] = .{
            .offset = attr.offset,
            .format = switch (attr.format) {
                .float2 => .FLOAT2,
                .float3 => .FLOAT3,
                .float4 => .FLOAT4,
                .ubyte4_norm => .UBYTE4N
            }
        };
    }

    const pipeline = gfx.makePipeline(.{
        .cull_mode = switch (d.cull_mode) { .front => .FRONT, .back => .BACK, .none => .NONE },
        .index_type = switch (d.index_type) { .none => .NONE, .uint16 => .UINT16, .uint32 => .UINT32 },
        .depth = .{ .write_enabled = d.depth_write },
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
