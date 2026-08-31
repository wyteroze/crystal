// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const uri_sep = "://";

const AssetUri = @This();
scheme: []const u8,
path: []const u8,

pub fn parse(allocator: std.mem.Allocator, uri: []const u8) !AssetUri {
    const idx = std.mem.find(u8, uri, uri_sep)
        orelse return error.InvalidUri;

    const scheme = try allocator.dupe(u8, uri[0..idx]);
    const path = try allocator.dupe(u8, uri[idx+3..]);

    return .{ .scheme = scheme, .path = path };
}

pub fn deinit(self: AssetUri, allocator: std.mem.Allocator) void {
    allocator.free(self.scheme);
    allocator.free(self.path);
}