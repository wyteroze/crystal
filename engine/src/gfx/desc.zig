// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const types = @import("types.zig");

pub const BufferDesc = struct {
    size: usize,
    type: types.BufferType = .vertex,
    usage: types.BufferUsage = .immutable,
    data: ?[]const u8 = null
};

pub const ImageDesc = struct {
    width: u32, height: u32,
    format: types.PixelFormat = .rgba8,
    data: ?[]const u8 = null
};

pub const VertexAttr = struct {
    offset: i32,
    format: VertexFormat
};

pub const VertexFormat = enum {
    float2,
    float3,
    float4,
    ubyte4_norm
};

pub const PipelineDesc = struct {
    shader: types.ShaderHandle,
    layout: []const VertexAttr,
    index_type: types.IndexType = .none,
    cull_mode: CullMode = .none,
    depth_write: bool = false
};

pub const CullMode = enum {
    none,
    front,
    back
};

pub const PassDesc = struct {
    width: u32, height: u32,
    clear_color: ?[4]f32 = null,
    clear_depth: ?f32 = null
};

pub const Bindings = struct {
    vertex_buffers: [4]?types.BufferHandle = @splat(null),
    index_buffer: ?types.BufferHandle = null,
    images: [4]?types.ImageHandle = @splat(null)
};

pub const Uniforms = struct {
    slot: u32,
    data: []const u8
};
