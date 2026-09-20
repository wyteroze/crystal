// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

const MouseDevice = @This();
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) MouseDevice {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *MouseDevice) void {
    _ = self;
}