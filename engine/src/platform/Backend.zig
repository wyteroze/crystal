// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const SdlBackend = @import("backends/SdlBackend.zig");

pub const Backend = union(enum) {
    sdl: SdlBackend,

    pub fn initSdl() Backend {
        return .{ .sdl = .{} };
    }
};
