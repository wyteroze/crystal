// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sokol = @import("sokol");
const types = @import("types.zig");
const desc = @import("desc.zig");
const Backend = @import("backend.zig").Backend;

const Renderer = @This();
backend: Backend,

pub fn init(b: Backend) Renderer {
    switch (b) {
        .sokol => |bk| bk.init()
    }

    return .{ .backend = b };
}

pub fn deinit(self: *Renderer) void {
    switch (self.backend) {
        .sokol => |b| b.deinit()
    }
}

pub fn createBuffer(self: *Renderer, d: desc.BufferDesc) types.BufferHandle {
    return switch (self.backend) {
        .sokol => |*b| b.createBuffer(d)
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
