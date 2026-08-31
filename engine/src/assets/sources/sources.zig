// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

// These are registered at runtime.
pub const sources = .{
    @import("CacheSource.zig"),
    @import("CwdSource.zig"),
    @import("PersistSource.zig"),
    @import("TempSource.zig"),
    @import("FileSource.zig")
};