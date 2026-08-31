// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const DirSource = @import("DirSource.zig");

pub const scheme = "file";
pub fn init(allocator: std.mem.Allocator, io: std.Io, _: anytype, assets_path: ?[]const u8) !DirSource {
    return .init(allocator, io, assets_path orelse "the assets path was not defined, `file` scheme uris can't be used");
}