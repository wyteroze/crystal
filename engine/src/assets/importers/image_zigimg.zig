// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("../types.zig");
const ImportLocation = @import("importers.zig").ImportLocation;
const zigimg = @import("zigimg");

pub fn importImage(allocator: std.mem.Allocator, io: std.Io, location: ImportLocation, path: []const u8) !types.Image {
    var read_buf: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    var image: zigimg.Image = switch (location) {
        .bytes => |b| try .fromMemory(allocator, b),
        .path => |p| try .fromFilePath(allocator, io, p, read_buf[0..])
    };
    defer image.deinit(allocator);

    if (image.isAnimation()) {
        std.log.err("Animated images are not supported yet.", .{});
        return error.AnimatedImagesUnsuported;
    }

    var data: std.ArrayList(f32) = try .initCapacity(allocator, image.pixels.len());
    defer data.deinit(allocator);
    var iter = image.iterator();
    while (iter.next()) |pix| {
        try data.appendSlice(allocator, &.{ pix.r, pix.g, pix.b, pix.a });
    }

    return .{
        .width = image.width, 
        .height = image.height,
        .data = try data.toOwnedSlice(allocator),
        .path = path 
    };
}