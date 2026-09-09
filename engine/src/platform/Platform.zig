// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const desc = @import("desc.zig");
const types = @import("types.zig");
const Backend = @import("Backend.zig").Backend;

const Platform = @This();
backend: Backend,

pub fn init(b: Backend) !Platform {
    switch (b) { inline else => |bk| bk.init() }

    return .{ .backend = b };
}

pub fn deinit(self: *Platform) void {
    switch (self.backend) { inline else => |*b| b.deinit() }
}

pub fn createSurface(self: *Platform, d: desc.SurfaceDesc) !types.SurfaceHandle {
    return switch (self.backend) { inline else => |*b| b.createSurface(d) };
}

pub fn getSurfacePixelSize(self: *Platform, h: types.SurfaceHandle) ![2]u32 {
    return switch (self.backend) { inline else => |*b| b.getSurfacePixelSize(h) };
}

pub fn destroySurface(self: *Platform, h: types.SurfaceHandle) void {
    switch (self.backend) { inline else => |*b| b.destroySurface(h) }
}

pub fn pollEvent(self: *Platform) ?desc.PlatformEvent {
    return switch (self.backend) { inline else => |*b| b.pollEvent() };
}