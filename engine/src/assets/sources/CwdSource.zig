// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const DirSource = @import("DirSource.zig");

pub const scheme = "cwd";
pub fn init(allocator: std.mem.Allocator, io: std.Io, _: anytype, _: anytype) !DirSource {
    return .init(allocator, io, ".");
}