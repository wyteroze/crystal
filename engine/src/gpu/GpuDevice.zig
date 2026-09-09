// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const sokol = @import("sokol");
const types = @import("types.zig");
const desc = @import("desc.zig");
const Backend = @import("backend.zig").Backend;

pub const GpuBuffer = struct {
    backend: Backend,
    handle: types.BufferHandle,

    pub fn init(b: Backend, d: desc.BufferDesc) !GpuBuffer {
        const handle = b.createBuffer(d);

        return .{ .backend = b, .handle = handle };
    }

    pub fn deinit(self: *GpuBuffer) void {
        self.backend.deleteBuffer(self.handle);
    }

    pub fn update(self: *GpuBuffer, data: []const u8) void {
        self.backend.updateBuffer(self.handle, data);
    }
};

pub const GpuSampler = struct {
    backend: Backend,
    handle: types.SamplerHandle,

    pub fn init(b: Backend, d: desc.SamplerDesc) !GpuSampler {
        const handle = b.createSampler(d);

        return .{ .backend = b, .handle = handle };
    }

    pub fn deinit(self: *GpuSampler) void {
        self.backend.deleteSampler(self.handle);
    }
};

pub const GpuImage = struct {
    backend: Backend,
    handle: types.ImageHandle,

    pub fn init(b: Backend, d: desc.ImageDesc) !GpuImage {
        const handle = b.createImage(d);

        return .{ .backend = b, .handle = handle };
    }

    pub fn deinit(self: *GpuImage) void {
        self.backend.deleteImage(self.handle);
    }
};

pub const GpuPipeline = struct {
    backend: Backend,
    handle: types.PipelineHandle,

    pub fn init(b: Backend, d: desc.PipelineDesc) !GpuPipeline {
        const handle = b.createPipeline(d);

        return .{ .backend = b, .handle = handle };
    }

    pub fn deinit(self: *GpuPipeline) void {
        self.backend.deletePipeline(self.handle);
    }

    pub fn apply(self: *GpuPipeline) void {
        self.backend.applyPipeline(self.handle);
    }

    pub fn applyBindings(self: *GpuPipeline, binds: desc.Bindings) void {
        self.backend.applyPipelineBindings(self.handle, binds);
    }

    pub fn draw(self: *GpuPipeline, base: u32, count: u32, instances: u32) void {
        self.backend.drawPipeline(self.handle, base, count, instances);
    }
};

pub const GpuShader = struct {
    backend: Backend,
    handle: types.ShaderHandle,

    pub fn init(b: Backend, d: desc.ShaderDesc) !GpuShader {
        const handle = b.createShader(d);

        return .{ .backend = b, .handle = handle };
    }

    pub fn deinit(self: *GpuShader) void {
        self.backend.deleteShader(self.handle);
    }
};

const GpuDevice = @This();
backend: Backend,

pub fn init(b: Backend) GpuDevice {
    return .{ .backend = b };
}

pub fn deinit(self: GpuDevice) void {
    self.backend.deinit();
}

pub fn createBuffer(self: GpuDevice, d: desc.BufferDesc) !GpuBuffer {
    return .init(self.backend, d);
}

pub fn createSampler(self: GpuDevice, d: desc.SamplerDesc) !GpuSampler {
    return .init(self.backend, d);
}

pub fn createImage(self: GpuDevice, d: desc.ImageDesc) !GpuImage {
    return .init(self.backend, d);
}

pub fn createPipeline(self: GpuDevice, d: desc.PipelineDesc) !GpuPipeline {
    return .init(self.backend, d);
}

pub fn createShader(self: GpuDevice, d: desc.ShaderDesc) !GpuShader {
    return .init(self.backend, d);
}

pub fn applyBindings(self: GpuDevice, b: desc.Bindings) void {
    self.backend.applyBindings(b);
}

pub fn beginPass(self: GpuDevice, d: desc.PassDesc) void {
    self.backend.beginPass(d);
}

pub fn endPass(self: GpuDevice) void {
    self.backend.endPass();
}

pub fn draw(self: GpuDevice, base: u32, count: u32, instances: u32) void {
    self.backend.draw(base, count, instances);
}

pub fn commit(self: GpuDevice) void {
    self.backend.commit();
}

pub fn present(self: GpuDevice) void {
    self.backend.present();
}