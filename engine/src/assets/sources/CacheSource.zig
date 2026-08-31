// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const DirSource = @import("DirSource.zig");
const Os = @import("../../os/Os.zig");

pub const scheme = "cache";
pub fn init(allocator: std.mem.Allocator, io: std.Io, os: Os, _: anytype) !DirSource {
    const path = try os.filesystem().getCachePath(allocator);
    defer allocator.free(path);

    return .init(allocator, io, path);
}