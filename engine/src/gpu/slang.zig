// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const c = @import("slang");
const desc = @import("desc.zig");

pub const TargetKind = enum {
    hlsl,
    glsl,
    spirv,

    fn toC(self: TargetKind) c_uint {
        return switch (self) {
            .hlsl => c.CRYSTAL_SLANG_TARGET_HLSL,
            .glsl => c.CRYSTAL_SLANG_TARGET_GLSL,
            .spirv => c.CRYSTAL_SLANG_TARGET_SPIRV
        };
    }

    pub fn fromBackend(backend: desc.Backend) TargetKind {
        return switch (backend) {
            .direct3d11, .direct3d12 => .hlsl,
            .opengl => .glsl,
            .vulkan => .spirv
        };
    }
};

pub const StageKind = enum {
    vertex,
    fragment,
    compute,

    fn toC(self: StageKind) c_uint {
        return switch (self) {
            .vertex => c.CRYSTAL_SLANG_STAGE_VERTEX,
            .fragment => c.CRYSTAL_SLANG_STAGE_FRAGMENT,
            .compute => c.CRYSTAL_SLANG_STAGE_COMPUTE
        };
    }
};

pub const CompileResult = struct {
    code: []const u8,
    raw: c.CrystalSlangCompileResult,

    pub fn deinit(self: *CompileResult) void {
        c.slang_free_result(self.raw);
    }
};

pub const ModuleLookupFn = *const fn (name: []const u8) ?[:0]const u8;

pub const Compiler = struct {
    handle: c.CrystalSlangCompilerHandle,
    vfs: ?*anyopaque = null,
    lookup_fn: ?ModuleLookupFn = null,

    pub fn init() Compiler {
        return .{ .handle = c.slang_compiler_create() };
    }

    pub fn deinit(self: *Compiler) void {
        if (self.vfs) |vfs| c.slang_vfs_destroy(vfs);
        c.slang_compiler_destroy(self.handle);
    }

    pub fn setModuleLookup(self: *Compiler, lookup_fn: ModuleLookupFn) void {
        self.lookup_fn = lookup_fn;
        self.vfs = c.slang_vfs_create(vfsLookup, self);
    }

    pub fn compileStage(self: Compiler, module_name: [:0]const u8, source: [:0]const u8, entrypoint: [:0]const u8, stage: StageKind, target: TargetKind) !CompileResult {
        const result = c.slang_compile_stage(
            self.handle,
            self.vfs,
            module_name.ptr,
            source.ptr,
            entrypoint.ptr,
            stage.toC(),
            target.toC()
        );

        if (result.error_message) |msg| {
            std.log.err("Slang compile error ({s}::{s}): {s}", .{ module_name, entrypoint, msg });
            return error.CompileFailed;
        }

        const code_ptr: [*]const u8 = @ptrCast(result.code_data.?);
        return .{
            .code = code_ptr[0..result.code_size],
            .raw = result
        };
    }
};

fn vfsLookup(userdata: ?*anyopaque, path: [*c]const u8, out_size: [*c]usize) callconv(.c) [*c]const u8 {
    const self: *Compiler = @ptrCast(@alignCast(userdata.?));
    const lookup_fn = self.lookup_fn orelse return null;

    const path_slice = std.mem.span(path);
    const stem = std.Io.Dir.path.stem(path_slice);

    if (lookup_fn(stem))|src| {
        out_size.* = src.len;
        return src.ptr;
    }

    return null;
}