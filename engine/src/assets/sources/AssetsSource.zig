// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const DirSource = @import("DirSource.zig");

pub const scheme = "assets";
pub fn init(allocator: std.mem.Allocator, io: std.Io) !DirSource {
    return .init(allocator, io, "."); // Gets set to project assets path if one is given in Assets.zig
}