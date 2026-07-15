// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const bmp_parser = @import("parsers/bmp.zig");

pub const ImageData = struct {
    pub const lua_ref = true;
    pub const hidden = .{ "width", "height", "pixels", "loadFromFile", "sample" };
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,

    // ARGB top to bottom
    pixels: []u32,

    pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !ImageData {
        var file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);

        var buffer: [4096]u8 = undefined;

        var file_reader = file.reader(io, &buffer);
        const reader = &file_reader.interface;

        const image_data = try bmp_parser.parseBmp(allocator, reader);
        return image_data;
    }

    pub fn deinit(self: ImageData) void {
        self.allocator.free(self.pixels);
    }

    /// U and V range from 0.0 - 1.0, other values
    /// are clamped.
    pub fn sample(self: ImageData, u: f32, v: f32) u32 {
        const cu = std.math.clamp(u, 0.0, 1.0);
        const cv = std.math.clamp(v, 0.0, 1.0);

        const x = @as(u32, @intFromFloat(cu * @as(f32, @floatFromInt(self.width - 1))));
        const y = @as(u32, @intFromFloat(cv * @as(f32, @floatFromInt(self.height - 1))));

        return self.pixels[y * self.width + x];
    }
};
