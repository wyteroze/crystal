// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const toml_parser = @import("parsers/toml.zig");

pub const TomlValue = toml_parser.TomlValue;
pub const TomlTable = toml_parser.TomlTable;

pub const TomlData = struct {
    allocator: std.mem.Allocator,
    root: *TomlTable,

    pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !TomlData {
        var file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);

        var buffer: [4096]u8 = undefined;

        var file_reader = file.reader(io, &buffer);
        const reader = &file_reader.interface;

        const root = try toml_parser.parseToml(allocator, reader);
        return .{ .allocator = allocator, .root = root };
    }

    /// Looks up a value by dot path (ex. "window.width")
    pub fn get(self: TomlData, path: []const u8) ?TomlValue {
        var current = self.root;
        var it = std.mem.splitScalar(u8, path, '.');

        while (it.next()) |segment| {
            const value = current.get(segment) orelse return null;
            if (it.rest().len == 0) return value;

            current = switch (value) {
                .table => |t| t,
                else => return null,
            };
        }

        return null;
    }

    pub fn deinit(self: *TomlData) void {
        toml_parser.deinitTable(self.root, self.allocator);
        self.allocator.destroy(self.root);
    }
};
