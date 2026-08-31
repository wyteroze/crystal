// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const SokolBackend = @import("backends/SokolBackend.zig");

pub const Backend = union(enum) {
    sokol: SokolBackend,

    pub fn initSokol(allocator: std.mem.Allocator) Backend {
        return .{ .sokol = .{ .allocator = allocator } };
    }
};
