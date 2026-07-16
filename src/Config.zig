// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const TomlData = @import("TomlData.zig").TomlData;
const TomlValue = @import("TomlData.zig").TomlValue;
const log = @import("log.zig").config;

pub const Config = struct {
    fps: u32,
    width: u16,
    height: u16,

    pub fn load(allocator: std.mem.Allocator, io: anytype, path: []const u8) !Config {
        var toml = TomlData.loadFromFile(allocator, io, path) catch |e| {
            log.err("Failed to load {s}: {s}", .{ path, @errorName(e) });
            return e;
        };
        defer toml.deinit();

        const fps = toml.get("window.fps") orelse blk: {
            log.warn("window.fps missing, defaulting to 60", .{});
            break :blk TomlValue{ .integer = 60 };
        };

        const resolution = (toml.get("window.resolution") orelse blk: {
            log.warn("window.resolution missing, defaulting to [ 540, 360 ]", .{});
            break :blk TomlValue{ .array = @constCast(&[_]TomlValue{ .{ .integer = 540 }, .{ .integer = 360 } }) };
        }).array;

        return .{
            .fps = @intCast(fps.integer),
            .width = @intCast(resolution[0].integer),
            .height = @intCast(resolution[1].integer),
        };
    }
};
