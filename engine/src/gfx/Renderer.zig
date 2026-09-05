// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const sokol = @import("sokol");
const types = @import("types.zig");
const desc = @import("desc.zig");
const Backend = @import("backend.zig").Backend;

const Renderer = @This();
backend: Backend,

pub fn init(b: Backend) Renderer {
    return .{ .backend = b };
}

pub fn start(self: *Renderer) void {
    switch (self.backend) {
        .sokol => |*bk| bk.init()
    }
}

pub fn deinit(self: *Renderer) void {
    switch (self.backend) {
        .sokol => |*b| b.deinit()
    }
}

pub fn createBuffer(self: *Renderer, d: desc.BufferDesc) types.BufferHandle {
    return switch (self.backend) {
        .sokol => |*b| b.createBuffer(d)
    };
}

pub fn createSampler(self: *Renderer, d: desc.SamplerDesc) types.SamplerHandle {
    return switch (self.backend) {
        .sokol => |*b| b.createSampler(d)
    };
}

pub fn createImage(self: *Renderer, d: desc.ImageDesc) types.ImageHandle {
    return switch (self.backend) {
        .sokol => |*b| b.createImage(d)
    };
}

pub fn createPipeline(self: *Renderer, d: desc.PipelineDesc) types.PipelineHandle {
    return switch (self.backend) {
        .sokol => |*b| b.createPipeline(d)
    };
}

pub fn createShader(self: *Renderer, d: sokol.gfx.ShaderDesc) types.ShaderHandle {
    return switch (self.backend) {
        .sokol => |*b| b.createShader(d)
    };
}

pub fn beginPass(self: *Renderer, d: desc.PassDesc) void {
    switch (self.backend) {
        .sokol => |*b| b.beginPass(d)
    }
}

pub fn applyPipeline(self: *Renderer, pipeline: types.PipelineHandle) void {
    switch (self.backend) {
        .sokol => |*b| b.applyPipeline(pipeline)
    }
}

pub fn applyBindings(self: *Renderer, binds: desc.Bindings) void {
    switch (self.backend) {
        .sokol => |*b| b.applyBindings(binds)
    }
}

pub fn applyUniforms(self: *Renderer, unis: desc.Uniforms) void {
    switch (self.backend) {
        .sokol => |*b| b.applyUniforms(unis)
    }
}

pub fn draw(self: *Renderer, base: u32, count: u32, instances: u32) void {
    switch (self.backend) {
        .sokol => |*b| b.draw(base, count, instances)
    }
}

pub fn endPass(self: *Renderer) void {
    switch (self.backend) {
        .sokol => |*b| b.endPass()
    }
}

pub fn commit(self: *Renderer) void {
    switch (self.backend) {
        .sokol => |*b| b.commit()
    }
}
