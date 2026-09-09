// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

pub const BufferHandle = struct { ptr: ?*anyopaque };
pub const ImageHandle = struct { ptr: ?*anyopaque };
pub const ShaderHandle = struct { ptr: ?*anyopaque };
pub const PipelineHandle = struct { ptr: ?*anyopaque };
pub const SamplerHandle = struct { ptr: ?*anyopaque };

pub const BufferUsage = enum { immutable, dynamic, stream };
pub const BufferType = enum { vertex, index, uniform };

pub const PixelFormat = enum {
    /// 4 channels, 8 bits each, 32 total.
    rgba8, 
    /// 4 channels, 16 bits each, 64 total.
    rgba16f, 
    /// Depth stencil
    /// 2 channels. 24 bits for depth, 8 bits for stencil, 32 total.
    d24_s8 
};

pub const IndexType = enum { none, uint16, uint32 };
pub const WrapType = enum { repeat, clamp };
pub const FilterType = enum { linear, nearest };