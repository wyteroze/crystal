// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const sokol = @import("sokol");
const slang = @import("slang.zig");
const shader_registry = @import("shaders/registry.zig");
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

    pub fn deinit(self: GpuBuffer) void {
        self.backend.deleteBuffer(self.handle);
    }

    pub fn update(self: GpuBuffer, data: []const u8) void {
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

    pub fn deinit(self: GpuSampler) void {
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

    pub fn deinit(self: GpuImage) void {
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

    pub fn deinit(self: GpuPipeline) void {
        self.backend.deletePipeline(self.handle);
    }

    pub fn apply(self: GpuPipeline) void {
        self.backend.applyPipeline(self.handle);
    }

    pub fn applyBindings(self: GpuPipeline, binds: desc.Bindings) void {
        self.backend.applyPipelineBindings(self.handle, binds);
    }

    pub fn draw(self: GpuPipeline, base: u32, count: u32, instances: u32) void {
        self.backend.drawPipeline(self.handle, base, count, instances);
    }
};

pub const GpuComputePipeline = struct {
    backend: Backend,
    handle: types.ComputePipelineHandle,

    pub fn init(b: Backend, d: desc.ComputePipelineDesc) !GpuComputePipeline {
        const handle = b.createComputePipeline(d);

        return .{ .backend = b, .handle = handle };
    }

    pub fn deinit(self: GpuComputePipeline) void {
        self.backend.deleteComputePipeline(self.handle);
    }

    pub fn apply(self: GpuComputePipeline) void {
        self.backend.applyComputePipeline(self.handle);
    }

    pub fn applyBindings(self: GpuComputePipeline, binds: desc.Bindings) void {
        self.backend.applyComputeBindings(self.handle, binds);
    }

    pub fn dispatch(self: GpuComputePipeline, group_x: u32, group_y: u32, group_z: u32) void {
        self.backend.dispatchCompute(self.handle, group_x, group_y, group_z);
    }
};

pub const GpuShader = struct {
    backend: Backend,
    handle: types.ShaderHandle,

    pub fn init(b: Backend, compiler: *slang.Compiler, d: desc.ShaderDesc) !GpuShader {
        var compiled_stages: [8]desc.ShaderStageDesc = undefined;
        var results: [8]slang.CompileResult = undefined;
        defer for (results[0..d.stages.len]) |*r| r.deinit();

        for (d.stages, 0..) |s, i| {
            results[i] = try compiler.compileStage(
                "shader", 
                s.source,
                s.entrypoint,
                switch (s.stage) { .vertex => .vertex, .fragment => .fragment, .compute => .compute }, 
                .fromBackend(b.queryBackend())
            );
            compiled_stages[i] = .{
                .name = s.name,
                .stage = s.stage,
                .source = @ptrCast(results[i].code),
                .entrypoint = s.entrypoint
            };
        }

        const handle = b.createShader(.{ .stages = compiled_stages[0..d.stages.len] });
        return .{ .backend = b, .handle = handle };
    }

    pub fn deinit(self: GpuShader) void {
        self.backend.deleteShader(self.handle);
    }
};

const GpuDevice = @This();
allocator: std.mem.Allocator,
backend: Backend,
compiler: *slang.Compiler,

pub fn init(allocator: std.mem.Allocator, b: Backend) !GpuDevice {
    const compiler = try allocator.create(slang.Compiler);
    compiler.* = .init();
    compiler.setModuleLookup(shader_registry.lookupShaderModule);

    return .{
        .allocator = allocator,
        .backend = b,
        .compiler = compiler
    };
}

pub fn deinit(self: GpuDevice) void {
    self.compiler.deinit();
    self.allocator.destroy(self.compiler);
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

pub fn createComputePipeline(self: GpuDevice, d: desc.ComputePipelineDesc) !GpuComputePipeline {
    return .init(self.backend, d);
}

pub fn createShader(self: GpuDevice, d: desc.ShaderDesc) !GpuShader {
    return .init(self.backend, self.compiler, d);
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