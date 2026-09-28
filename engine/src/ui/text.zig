// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("types.zig");
const math = @import("../core/math/math.zig");
const FontAtlas = @import("../render/text/FontAtlas.zig");

pub const GlyphQuad = struct {
    pos: [2]f32,
    size: [2]f32,
    uv_pos: [2]f32,
    uv_size: [2]f32
};

pub fn lineHeight(atlas: *const FontAtlas, size: u32) f32 {
    const scale = atlas.calculateScale(size);
    return (atlas.ascent + atlas.descent + atlas.line_gap) * scale;
}

pub fn ascent(atlas: *const FontAtlas, size: u32) f32 {
    const scale = atlas.calculateScale(size);
    return (atlas.ascent + atlas.line_gap/2) * scale;
}

pub fn measureWidth(atlas: *const FontAtlas, txt: []const u8, size: u32) f32 {
    if (txt.len == 0) return 0;
    const scale = atlas.calculateScale(size);

    var cur_x: f32 = 0;
    for (txt) |ch| {
        if (ch < 32 or ch > 126) continue;
        const glyph = atlas.glyphs.get(ch) orelse continue;
        
        cur_x += glyph.advance;
    }

    return cur_x * scale;
}

pub fn measureText(atlas: *const FontAtlas, txt: []const u8, size : u32) math.Vec2 {
    if (txt.len == 0) return .zero;

    return .new(
        measureWidth(atlas, txt, size),
        lineHeight(atlas, size)
    );
}

/// Caller owns the returned slice and the data in it.
pub fn layoutGlyphs(
    allocator: std.mem.Allocator,
    atlas: *const FontAtlas,
    t: types.Text,
    origin: math.Vec2,
    size: math.Vec2
) ![]GlyphQuad {
    const scale = atlas.calculateScale(t.size);
    const text_w = measureWidth(atlas, t.content, t.size);
    const line_h = lineHeight(atlas, t.size);
    const asc = ascent(atlas, t.size);

    const start_x = switch (t.align_text) {
        .start => origin.x,
        .center => origin.x + (size.x - text_w) / 2,
        .end => origin.x + size.x - text_w
    };
    const top_y = switch (t.justify) {
        .start => origin.y,
        .center => origin.y + (size.y - line_h) / 2,
        .end, .space_between => origin.y  + size.y - line_h
    };

    const baseline = @round(top_y + asc);
    var quads: std.ArrayList(GlyphQuad) = .empty;
    var cur_x = start_x;

    for (t.content) |ch| {
        if (ch < 32 or ch > 126) continue;
        const glyph = atlas.glyphs.get(ch) orelse continue;

        try quads.append(allocator, .{
            .pos = .{ cur_x + glyph.bearing[0] * scale, baseline - glyph.bearing[1] * scale },
            .size = .{ glyph.size[0] * scale, glyph.size[1] * scale },
            .uv_pos = glyph.uv_pos,
            .uv_size = glyph.uv_size
        });

        cur_x += glyph.advance * scale;
    }

    return quads.toOwnedSlice(allocator);
}