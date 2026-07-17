// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const ImageData = @import("../ImageData.zig").ImageData;
const TomlData = @import("../TomlData.zig").TomlData;
const TomlValue = @import("../TomlData.zig").TomlValue;
const Glyph = @import("Glyph.zig").Glyph;
const Vec2 = @import("../script/objects/Vec2.zig").Vec2;
const log = @import("../log.zig").font;

const map_name = "map.toml";

pub const TextSize = struct { w: u32, h: u32 };

pub const Font = struct {
    pub const lua_ref = true;
    pub const name = "Font";
    pub const hidden = .{ "sheet", "glyphs", "loadFromFile", "measure" };

    allocator: std.mem.Allocator,
    sheet: *const ImageData,
    glyphs: std.AutoHashMap(u21, Glyph),
    line_height: u32,

    /// `folder_path` is the folder that `map.toml` lives in, and must be suffixed with a slash.
    pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, folder_path: []const u8) !*Font {
        const map_path = try std.mem.concat(allocator, u8, &.{ folder_path, map_name });
        defer allocator.free(map_path);

        var map = try TomlData.loadFromFile(allocator, io, map_path);
        defer map.deinit();

        const sheet_name = switch (map.get("info.map") orelse return error.MissingImage) {
            .string => |s| s,
            else => return error.InvalidImageField,
        };
        const sheet_path = try std.mem.concat(allocator, u8, &.{ folder_path, sheet_name });
        defer allocator.free(sheet_path);

        const sheet = try allocator.create(ImageData);
        errdefer allocator.destroy(sheet);
        sheet.* = try ImageData.loadFromFile(allocator, io, sheet_path);
        errdefer sheet.deinit();

        const line_height: u32 = switch (map.get("info.line_height") orelse return error.LineHeightUndefined) {
            .integer => |i| @intCast(i),
            else => return error.LineHeightUndefined,
        };

        var glyphs = std.AutoHashMap(u21, Glyph).init(allocator);
        errdefer glyphs.deinit();

        const glyphs_tbl = switch (map.get("glyphs") orelse return error.MissingGlyphs) {
            .table => |t| t,
            else => return error.InvalidGlyphsTable,
        };

        // `char = [ [posX, posY], [sizeX, sizeY], advance ]`
        var it = glyphs_tbl.iterator();
        while (it.next()) |entry| {
            const key = std.mem.trim(u8, entry.key_ptr.*, "\"");
            const code_point = try firstCodepoint(key);

            const arr = switch (entry.value_ptr.*) {
                .array => |a| a,
                else => return error.InvalidGlyphEntry,
            };
            if (arr.len < 3) return error.InvalidGlyphEntry;

            const pos = switch (arr[0]) {
                .array => |a| a,
                else => return error.InvalidGlyphEntry,
            };
            if (pos.len < 2) return error.InvalidGlyphEntry;

            const size = switch (arr[1]) {
                .array => |a| a,
                else => return error.InvalidGlyphEntry
            };
            if (size.len < 2) return error.InvalidGlyphEntry;

            const pos_x = try asU32(pos[0]);
            const pos_y = try asU32(pos[1]);

            const size_x = try asU32(size[0]);
            const size_y = try asU32(size[1]);

            try glyphs.put(code_point, .{
                .pos_x = pos_x, .pos_y = pos_y,
                .size_x = size_x, .size_y = size_y,

                .advance = try asU32(arr[2]),
            });
        }

        const font = try allocator.create(Font);
        font.* = .{
            .allocator = allocator,
            .sheet = sheet,
            .glyphs = glyphs,
            .line_height = line_height,
        };

        log.info("loaded font '{s}': {d} glyphs, line height {d}", .{ folder_path, glyphs.count(), line_height });
        return font;
    }

    pub fn glyph(self: Font, codepoint: u21) ?Glyph {
        return self.glyphs.get(codepoint);
    }

    pub fn measure(self: Font, text: []const u8) !TextSize {
        var width: u32 = 0;
        var view = (try std.unicode.Utf8View.init(text)).iterator();
        while (view.nextCodepoint()) |codepoint| {
            if (self.glyphs.get(codepoint)) |g| width += g.advance;
        }

        return .{ .w = width, .h = self.line_height };
    }

    pub fn MeasureText(self: Font, text: []const u8) !Vec2 {
        const m = try self.measure(text);

        return Vec2.init(@floatFromInt(m.w), @floatFromInt(m.h));
    }

    pub fn deinit(self: *Font) void {
        self.glyphs.deinit();
        self.sheet.deinit();
        self.allocator.destroy(self.sheet);
        self.allocator.destroy(self);
    }
};

inline fn asU32(v: TomlValue) !u32 {
    return switch (v) {
        .integer => |i| @intCast(i),
        else => error.InvalidGlyphEntry,
    };
}

fn firstCodepoint(s: []const u8) !u21 {
    if (s.len == 0) return error.EmptyGlyphKey;
    const len = try std.unicode.utf8ByteSequenceLength(s[0]);

    return std.unicode.utf8Decode(s[0..len]);
}
