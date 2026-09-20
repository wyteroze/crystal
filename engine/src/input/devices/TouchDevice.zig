// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

const TouchDevice = @This();
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) TouchDevice {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *TouchDevice) void {
    _ = self;
}