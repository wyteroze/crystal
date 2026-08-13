// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const desc = @import("desc.zig");
const types = @import("types.zig");
const Backend = @import("Backend.zig").Backend;

const Platform = @This();
backend: Backend,

pub fn init(b: Backend) !Platform {
    switch (b) {
        .sdl => |bk| try bk.init()
    }

    return .{ .backend = b };
}

pub fn deinit(self: *Platform) void {
    switch (self.backend) {
        .sdl => |*b| b.deinit()
    }
}

pub fn createSurface(self: *Platform, d: desc.SurfaceDesc) !types.SurfaceHandle {
    return switch (self.backend) {
        .sdl => |*b| b.createSurface(d)
    };
}

pub fn destroySurface(self: *Platform, h: types.SurfaceHandle) void {
    switch (self.backend) {
        .sdl => |*b| b.destroySurface(h)
    }
}

pub fn pollEvent(self: *Platform) ?desc.PlatformEvent {
    return switch (self.backend) {
        .sdl => |*b| b.pollEvent()
    };
}

pub fn swapBuffers(self: *Platform, h: types.SurfaceHandle) !void {
    switch (self.backend) {
        .sdl => |*b| try b.swapBuffers(h)
    }
}

pub fn getElapsedSeconds(self: *Platform) f64 {
    return switch (self.backend) {
        .sdl => |*b| b.getElapsedSeconds()
    };
}
