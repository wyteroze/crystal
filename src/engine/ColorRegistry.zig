// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const TomlData = @import("../TomlData.zig").TomlData;
const Color = @import("../Color.zig").Color;

const colors_path = "src/data/colors.toml";

pub const ColorRegistry = struct {
    colors: std.StringHashMap(u32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) !ColorRegistry {
        var data = try TomlData.loadFromFile(allocator, io, colors_path);
        defer data.deinit();

        var map = std.StringHashMap(u32).init(allocator);
        errdefer {
            var it = map.iterator();
            while (it.next()) |entry| allocator.free(entry.key_ptr.*);
            map.deinit();
        }

        var it = data.root.iterator();
        while (it.next()) |entry| {
            const key = std.mem.trim(u8, entry.key_ptr.*, "\"");
            const hex = switch (entry.value_ptr.*) {
                .string => |s| std.mem.trimStart(u8, s, "#"),
                else => continue,
            };

            const rgb = std.fmt.parseInt(u32, hex, 16) catch continue;
            try map.put(try allocator.dupe(u8, key), rgb);
        }

        return .{ .colors = map, .allocator = allocator };
    }

    pub fn deinit(self: *ColorRegistry) void {
        var it = self.colors.iterator();
        while (it.next()) |entry| self.allocator.free(entry.key_ptr.*);

        self.colors.deinit();
    }

    pub fn named(self: ColorRegistry, color_name: []const u8, alpha: u8) ?Color {
        const rgb = self.colors.get(color_name) orelse return null;
        return .{ .color = (@as(u32, alpha) << 24) | rgb };
    }
};
