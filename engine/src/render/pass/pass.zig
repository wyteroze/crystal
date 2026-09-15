// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../../gpu/gpu.zig");
const types = @import("../types.zig");
const resource = @import("../resource.zig");

pub const ForwardPass = @import("ForwardPass.zig");
pub const DepthPrepassPass = @import("DepthPrepassPass.zig");
pub const LightCullPass = @import("LightCullPass.zig");
pub const SkyboxPass = @import("SkyboxPass.zig");
pub const UiPass = @import("UiPass.zig");

pub const PassContext = struct {
    device: *gpu.GpuDevice,
    view: *const types.RenderView,
    scene: *const types.RenderScene,
    resources: *resource.ResourceTable,
    frame_allocator: std.mem.Allocator
};

pub const PassNode = struct {
    ptr: *anyopaque,
    reads: []const resource.ResourceRef,
    writes: []const resource.ResourceRef,
    after: []const []const u8 = &.{},
    name: []const u8,

    execute_fn: *const fn (ptr: *anyopaque, ctx: PassContext) void,
    deinit_fn: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,

    pub fn execute(self: PassNode, ctx: PassContext) void {
        self.execute_fn(self.ptr, ctx);
    }

    pub fn deinit(self: PassNode, allocator: std.mem.Allocator) void {
        self.deinit_fn(self.ptr, allocator);
    }
};