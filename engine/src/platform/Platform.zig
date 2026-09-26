// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
pub const desc = @import("desc.zig");
pub const types = @import("types.zig");
pub const Backend = @import("Backend.zig").Backend;
const signal = @import("../core/signal.zig");

const Platform = @This();
backend: Backend,
platform_event: signal.Signal(.{ desc.PlatformEvent }),

pub fn init(allocator: std.mem.Allocator, b: Backend) !Platform {
    switch (b) { inline else => |bk| bk.init() }

    return .{ .backend = b, .platform_event = .init(allocator) };
}

pub fn deinit(self: *Platform) void {
    switch (self.backend) { inline else => |*b| b.deinit() }
    self.platform_event.deinit();
}

pub fn createSurface(self: *Platform, d: desc.SurfaceDesc) !types.SurfaceHandle {
    return switch (self.backend) { inline else => |*b| b.createSurface(d) };
}

pub fn getSurfacePixelSize(self: *Platform, h: types.SurfaceHandle) ![2]u32 {
    return switch (self.backend) { inline else => |*b| b.getSurfacePixelSize(h) };
}

pub fn getSurfaceLogicalSize(self: *Platform, h: types.SurfaceHandle) ![2]u32 {
    return switch (self.backend) { inline else => |*b| b.getSurfaceLogicalSize(h) };
}

pub fn getSurfaceScale(self: *Platform, h: types.SurfaceHandle) !f32 {
    return switch (self.backend) { inline else => |*b| b.getSurfaceScale(h) };
}

pub fn destroySurface(self: *Platform, h: types.SurfaceHandle) void {
    switch (self.backend) { inline else => |*b| b.destroySurface(h) }
}

pub fn poll(self: *Platform) void {
    while (switch (self.backend) { inline else => |*b| b.pollEvent() }) |e| {
        self.platform_event.fire(.{ e });
    }
}

pub fn showError(self: Platform, msg: [:0]const u8) void {
    switch (self.backend) { inline else => |*b| b.showError(msg) }
}

pub fn setCursorLocked(self: Platform, mode: bool) void {
    switch (self.backend) { inline else => |*b| b.setCursorLocked(mode) }
}

pub fn getCursorLocked(self: Platform) bool {
    return switch (self.backend) { inline else => |*b| b.getCursorLocked() };
}

pub fn setCursorVisible(self: Platform, mode: bool) void {
    switch (self.backend) { inline else => |*b| b.setCursorVisible(mode) }
}

pub fn getCursorVisible(self: Platform) bool {
    return switch (self.backend) { inline else => |*b| b.getCursorVisible() };
}