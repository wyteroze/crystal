// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const core = @import("../core/core.zig");
const types = @import("types.zig");

pub const BufferDesc = struct {
    name: [:0]const u8,
    type: types.BufferType = .vertex,
    usage: types.BufferUsage = .immutable,
    data: ?[]const u8 = null,
    size: usize = 0
};

pub const SamplerDesc = struct {
    wrap_u: types.WrapType = .repeat,
    wrap_v: types.WrapType = .repeat,
    mag_filter: types.FilterType = .linear,
    min_filter: types.FilterType = .linear,
    mip_filter: types.FilterType = .linear
};

pub const ImageDesc = struct {
    name: [:0]const u8,
    width: u32, height: u32,
    format: types.PixelFormat,
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
    name: [:0]const u8,
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
    clear_color: ?core.Color = null,
    clear_depth: ?f32 = null
};

pub const Bindings = struct {
    vertex_buffers: [4]?types.BufferHandle = @splat(null),
    index_buffer: ?types.BufferHandle = null,
    uniform_buffers: [4]?types.BufferHandle = @splat(null),
    images: [4]?types.ImageHandle = @splat(null),
    samplers: [4]?types.SamplerHandle = @splat(null)
};

pub const ShaderStage = enum {
    vertex,
    fragment
};

pub const ShaderStageDesc = struct {
    stage: ShaderStage,
    source: [:0]const u8,
    entrypoint: [:0]const u8 = "main"
};

pub const ShaderDesc = struct {
    stages: []const ShaderStageDesc
};