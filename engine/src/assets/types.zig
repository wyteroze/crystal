// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../gpu/gpu.zig");
const math = @import("../core/math/math.zig");
const text = @import("../render/text/text.zig");

pub const Vertex = extern struct {
    position: [3]f32,
    normal: [3]f32,
    uv: [2]f32
};

pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,

    pub fn deinit(self: *const Mesh, allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.indices);
    }
};

pub const Image = struct {
    width: usize, 
    height: usize,
    format: gpu.types.PixelFormat,
    data: []u8,

    pub fn bytes(self: *const Image, comptime T: type) []T {
        return std.mem.bytesAsSlice(T, self.data);
    }

    pub fn deinit(self: *const Image, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub const ScriptSource = struct {
    type: enum { text, bytecode },
    data: []const u8,

    pub fn deinit(self: *const ScriptSource, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub const Glyph = struct {
    codepoint: u32,
    size: [2]u32,
    bearing: [2]i32,
    advance: f32,
    pixels: []u8
};

pub const Font = struct {
    glyphs: []Glyph,
    ascent: f32,
    descent: f32,
    line_gap: f32,

    pub fn deinit(self: *const Font, allocator: std.mem.Allocator) void {
        for (self.glyphs) |g| allocator.free(g.pixels);
        allocator.free(self.glyphs);
    }
};

pub const AudioFormat = enum { mp3, wav };

pub const AudioStream = struct {
    pub const Source = union(enum) {
        decoded: []const f32,
        streamed: StreamSource,
    };

    pub const StreamSource = struct {
        format: AudioFormat,
        bytes: []const u8,
        total_frames: u64,
    };

    source: Source,
    sample_rate: u32,
    channels: u8,
    duration: f64,

    pub fn frameCount(self: *const AudioStream) usize {
        return switch (self.source) {
            .decoded => |s| s.len / self.channels,
            .streamed => |s| @intCast(s.total_frames),
        };
    }

    pub fn deinit(self: *const AudioStream, allocator: std.mem.Allocator) void {
        switch (self.source) {
            .decoded => |s| allocator.free(s),
            .streamed => |s| allocator.free(s.bytes),
        }
    }
};

// GPU-specific. Stored in GPU memory

pub const GpuImage = gpu.GpuDevice.GpuImage;
pub const GpuMesh = struct {
    vertex_buffer: gpu.GpuDevice.GpuBuffer,
    index_buffer: gpu.GpuDevice.GpuBuffer,
    vertex_count: u32,
    index_count: u32,

    pub fn deinit(self: GpuMesh) void {
        self.vertex_buffer.deinit();
        self.index_buffer.deinit();
    }
};
