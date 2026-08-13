// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const SokolBackend = @import("backends/SokolBackend.zig");

pub const Backend = union(enum) {
    sokol: SokolBackend,

    pub fn initSokol() Backend {
        return .{ .sokol = .{} };
    }
};
