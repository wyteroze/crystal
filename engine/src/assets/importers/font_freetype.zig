// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ImportLocation = @import("importers.zig").ImportLocation;
const types = @import("../types.zig");
const freetype = @import("freetype");

pub const ImportOptions = struct {
    pixel_size: u32,
    char_range: []const u32 = &default_char_range
};

// Ascii 32-126
const default_char_range = blk: {
    var range: [95]u32 = undefined;
    for (&range, 0..) |*c, i| c.* = 32 + i;

    break :blk range;
};

pub fn importFont(allocator: std.mem.Allocator, location: ImportLocation, options: ImportOptions) !types.Font {
    var lib = std.mem.zeroes(freetype.FT_Library);
    if (freetype.FT_Init_FreeType(&lib) != 0) return error.FreeTypeInitFailed;
    defer _ = freetype.FT_Done_FreeType(lib);

    var face = std.mem.zeroes(freetype.FT_Face);
    switch (location) {
        .path => |p| {
            const path_z = try allocator.dupeSentinel(u8, p, 0);
            defer allocator.free(path_z);

            if (freetype.FT_New_Face(lib, path_z, 0, &face) != 0) return error.ImportFailed;
        },
        .bytes => |b| {
            if (freetype.FT_New_Memory_Face(lib, b.ptr, @intCast(b.len), 0, &face) != 0) return error.ImportFailed;
        }
    }
    defer _ = freetype.FT_Done_Face(face);

    if (freetype.FT_Set_Pixel_Sizes(face, 0, options.pixel_size) != 0) return error.SetPixelSizeFailed;

    var glyphs = try allocator.alloc(types.Glyph, options.char_range.len);
    errdefer allocator.free(glyphs);

    var glyph_count: usize = 0;
    errdefer for (glyphs[0..glyph_count]) |g| allocator.free(g.pixels);

    for (options.char_range) |cp| { // Codepoint
        const glyph_index = freetype.FT_Get_Char_Index(face, cp);
        if (glyph_index == 0) continue;

        if (freetype.FT_Load_Glyph(face, glyph_index, freetype.FT_LOAD_DEFAULT) != 0) return error.GlyphLoadFailed;
        if (freetype.FT_Render_Glyph(face.*.glyph, freetype.FT_RENDER_MODE_NORMAL) != 0) return error.GlyphRenderFailed;

        const slot = face.*.glyph;
        const bitmap = slot.*.bitmap;

        const width: usize = bitmap.width;
        const rows: usize = bitmap.rows;
        const pitch: usize = @intCast(bitmap.pitch);

        var pixels = try allocator.alloc(u8, width * rows);
        errdefer allocator.free(pixels);

        for (0..rows) |y| {
            const src_row = bitmap.buffer[(y * pitch)..][0..width];
            @memcpy(pixels[(y * width)..][0..width], src_row);
        }

        glyphs[glyph_count] = .{
            .codepoint = cp,
            .size = .{ @intCast(width), @intCast(rows) },
            .bearing = .{ slot.*.bitmap_left, slot.*.bitmap_top },
            .advance = @as(f32, @floatFromInt(slot.*.advance.x)) / 64.0,
            .pixels = pixels
        };
        glyph_count += 1;
    }

    glyphs = try allocator.realloc(glyphs, glyph_count);
    return .{ .glyphs = glyphs, .pixel_size = options.pixel_size };
}