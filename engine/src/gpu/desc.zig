// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const core = @import("../core/core.zig");
const types = @import("types.zig");

pub const Backend = enum {
    opengl,
    direct3d11,
    direct3d12,
    vulkan
};

pub const ResourceKind = enum { uniform_buffer, storage_buffer, texture, sampler };
pub const ResourceVisibility = enum { vertex, fragment, compute, vertex_fragment };

pub const ResourceDesc = struct {
    name: [:0]const u8,
    kind: ResourceKind,
    visibility: ResourceVisibility
};

pub const BoundResource = struct {
    name: [:0]const u8,
    handle: union(ResourceKind) {
        uniform_buffer: types.BufferHandle,
        storage_buffer: types.BufferHandle,
        texture: types.ImageHandle,
        sampler: types.SamplerHandle
    }
};

pub const BufferDesc = struct {
    name: [:0]const u8,
    type: types.BufferType = .vertex,
    usage: types.BufferUsage = .immutable,
    data: ?[]const u8 = null,
    size: usize = 0,
    /// This usually isn't needed unless type == .storage, otherwise it's the byte size of one element.
    stride: usize = 0
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
    resources: []const ResourceDesc,
    index_type: types.IndexType = .none,
    cull_mode: CullMode = .none,
    depth_write: bool = false
};

pub const ComputePipelineDesc = struct {
    name: [:0]const u8,
    shader: types.ShaderHandle,
    resources: []const ResourceDesc
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

// TODO: The [4] (or similar in other places) is a remnant
// of what SokolBackend required, they should be turned into regular
// []'s in the future.
pub const Bindings = struct {
    vertex_buffers: [4]?types.BufferHandle = @splat(null),
    index_buffer: ?types.BufferHandle = null,
    resources: []const BoundResource = &.{}
};

pub const ShaderStage = enum {
    vertex,
    fragment,
    compute
};

pub const ShaderStageDesc = struct {
    name: [:0]const u8,
    stage: ShaderStage,
    source: [:0]const u8,
    entrypoint: [:0]const u8 = "main"
};

pub const ShaderDesc = struct {
    stages: []const ShaderStageDesc
};