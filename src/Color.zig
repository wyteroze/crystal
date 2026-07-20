// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const TomlData = @import("TomlData.zig").TomlData;
const ColorRegistry = @import("engine/ColorRegistry.zig").ColorRegistry;

pub const Color = struct {
    pub const name = "ColorObject";
    pub const hidden = .{ "color", "loadNames", "deinitNames", "named", "fromARGB", "fromHex" };
    pub var registry: *ColorRegistry = undefined;
    hex_buf: []u8 = undefined,
    color: u32,

    pub fn fromARGB(a: u8, r: u8, g: u8, b: u8) Color {
        return .{ .color = (@as(u32, a) << 24) | (@as(u32, r) << 16) | (@as(u32, g) << 8) | b };
    }

    pub fn fromHex(hexCode: []const u8) !Color {
        var hex = hexCode;
        if (hex.len >= 2 and hex[0] == '0' and (hex[1] == 'x' or hex[1] == 'X')) hex = hex[2..];

        return .{ .color = std.fmt.parseInt(u32, hex, 16) catch return error.InvalidHex };
    }

    pub fn GetName(self: Color) []const u8 {
        const r: i32 = @intCast((self.color >> 16) & 0xFF);
        const g: i32 = @intCast((self.color >> 8) & 0xFF);
        const b: i32 = @intCast(self.color & 0xFF);

        var best: []const u8 = "Black";
        var best_dist: i32 = std.math.maxInt(i32);

        var it = registry.colors.iterator();
        while (it.next()) |entry| {
            const rgb = entry.value_ptr.*;

            const dr = r - @as(i32, @intCast((rgb >> 16) & 0xFF));
            const dg = g - @as(i32, @intCast((rgb >> 8) & 0xFF));
            const db = b - @as(i32, @intCast(rgb & 0xFF));

            const dist = dr * dr + dg * dg + db * db;
            if (dist < best_dist) {
                best_dist = dist;
                best = entry.key_ptr.*;
            }
        }

        return best;
    }

    pub fn GetARGB(self: Color) struct { u8, u8, u8, u8 } {
        return .{
            @truncate(self.color >> 24),
            @truncate(self.color >> 16),
            @truncate(self.color >> 8),
            @truncate(self.color),
        };
    }

    pub fn GetHex(self: Color) []const u8 {
        const a: u8 = @truncate(self.color >> 24);
        const r: u8 = @truncate(self.color >> 16);
        const g: u8 = @truncate(self.color >> 8);
        const b: u8 = @truncate(self.color);

        return std.fmt.bufPrint(self.hex_buf, "{X:0>2}{X:0>2}{X:0>2}{X:0>2}", .{ a, r, g, b }) catch unreachable;
    }

    pub fn format(self: Color, writer: *std.Io.Writer) !void {
        try writer.print("#{s}", .{self.GetHex()});
    }
};
