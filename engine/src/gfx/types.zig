// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

pub const BufferHandle = struct { id: u32 };
pub const ImageHandle = struct { id: u32 };
pub const ShaderHandle = struct { id: u32 };
pub const PipelineHandle = struct { id: u32 };

pub const BufferUsage = enum { immutable, dynamic, stream };
pub const BufferType = enum { vertex, index };

pub const PixelFormat = enum { rgba8, depth_stencil };

pub const IndexType = enum { none, uint16, uint32 };
