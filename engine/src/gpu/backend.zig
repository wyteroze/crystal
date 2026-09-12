// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const desc = @import("desc.zig");
const types = @import("types.zig");

const DiligentBackend = @import("backends/DiligentBackend.zig");

pub const Backend = union(enum) {
    diligent: DiligentBackend,

    pub fn initDiligent(surface_handle: ?*anyopaque, surface_size: [2]u32) Backend {
        return .{ .diligent = .init(surface_handle, surface_size) };
    }

    pub fn deinit(self: Backend) void {
        switch (self) { inline else => |b| b.deinit() }
    }

    pub fn createBuffer(self: Backend, d: desc.BufferDesc) types.BufferHandle {
        return switch (self) { inline else => |b| b.createBuffer(d) };
    }

    pub fn deleteBuffer(self: Backend, h: types.BufferHandle) void {
        return switch (self) { inline else => |b| b.destroyBuffer(h) };
    }

    pub fn updateBuffer(self: Backend, h: types.BufferHandle, data: []const u8) void {
        return switch (self) { inline else => |b| b.updateBuffer(h, data) };
    }

    pub fn createSampler(self: Backend, d: desc.SamplerDesc) types.SamplerHandle {
        return switch (self) { inline else => |b| b.createSampler(d) };
    }

    pub fn deleteSampler(self: Backend, h: types.SamplerHandle) void {
        return switch (self) { inline else => |b| b.destroySampler(h) };
    }

    pub fn createImage(self: Backend, d: desc.ImageDesc) types.ImageHandle {
        return switch (self) { inline else => |b| b.createImage(d) };
    }

    pub fn deleteImage(self: Backend, h: types.ImageHandle) void {
        return switch (self) { inline else => |b| b.destroyImage(h) };
    }

    pub fn createShader(self: Backend, d: desc.ShaderDesc) types.ShaderHandle {
        return switch (self) { inline else => |b| b.createShader(d) };
    }

    pub fn deleteShader(self: Backend, h: types.ShaderHandle) void {
        return switch (self) { inline else => |b| b.destroyShader(h) };
    }

    pub fn beginPass(self: Backend, d: desc.PassDesc) void {
        switch (self) { inline else => |b| b.beginPass(d) }
    }

    pub fn createPipeline(self: Backend, d: desc.PipelineDesc) types.PipelineHandle {
        return switch (self) { inline else => |b| b.createPipeline(d) };
    }

    pub fn deletePipeline(self: Backend, h: types.PipelineHandle) void {
        return switch (self) { inline else => |b| b.destroyPipeline(h) };
    }

    pub fn applyPipeline(self: Backend, pipeline: types.PipelineHandle) void {
        switch (self) { inline else => |b| b.applyPipeline(pipeline) }
    }

    pub fn applyPipelineBindings(self: Backend, pipeline: types.PipelineHandle, binds: desc.Bindings) void {
        switch (self) { inline else => |b| b.applyPipelineBindings(pipeline, binds) }
    }

    pub fn drawPipeline(self: Backend, pipeline: types.PipelineHandle, base: u32, count: u32, instances: u32) void {
        switch (self) { inline else => |b| b.drawPipeline(pipeline, base, count, instances) }
    }

    pub fn createComputePipeline(self: Backend, d: desc.ComputePipelineDesc) types.ComputePipelineHandle {
        return switch (self) { inline else => |b| b.createComputePipeline(d) };
    }

    pub fn deleteComputePipeline(self: Backend, h: types.ComputePipelineHandle) void {
        return switch (self) { inline else => |b| b.destroyComputePipeline(h) };
    }

    pub fn applyComputePipeline(self: Backend, h: types.ComputePipelineHandle) void {
        switch (self) { inline else => |b| b.applyComputePipeline(h) }
    }

    pub fn applyComputeBindings(self: Backend, h: types.ComputePipelineHandle, binds: desc.Bindings) void {
        switch (self) { inline else => |b| b.applyComputeBindings(h, binds) }
    }

    pub fn dispatchCompute(self: Backend, h: types.ComputePipelineHandle, groups_x: u32, groups_y: u32, groups_z: u32) void {
        switch (self) { inline else => |b| b.dispatchCompute(h, groups_x, groups_y, groups_z) }
    }

    pub fn endPass(self: Backend) void {
        switch (self) { inline else => |b| b.endPass() }
    }

    pub fn present(self: Backend) void {
        switch (self) { inline else => |b| b.present() }
    }

    pub fn queryBackend(self: Backend) desc.Backend {
        return switch (self) { inline else => |b| b.queryBackend() };
    }
};
