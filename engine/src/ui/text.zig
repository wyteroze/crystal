// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
// TODO: Switch to unicode asap!!

const std = @import("std");
const types = @import("types.zig");
const math = @import("../core/math/math.zig");
const FontAtlas = @import("../render/text/FontAtlas.zig");

pub const GlyphQuad = struct {
    pos: [2]f32,
    size: [2]f32,
    uv_pos: [2]f32,
    uv_size: [2]f32,
};

pub const LineIterator = struct {
    pub const Line = struct { text: []const u8, width: f32 };

    atlas: *const FontAtlas,
    txt: []const u8,
    scale: f32,
    max_width: ?f32,
    pos: usize = 0,

    pub fn init(atlas: *const FontAtlas, txt: []const u8, size: f32, max_width: ?f32) LineIterator {
        return .{
            .atlas = atlas,
            .txt = txt,
            .scale = atlas.calculateScale(size),
            .max_width = max_width,
        };
    }

    fn advance(self: *const LineIterator, ch: u8) f32 {
        if (ch < 32 or ch > 126) return 0;
        const g = self.atlas.glyphs.get(ch) orelse return 0;
        return g.advance * self.scale;
    }

    pub fn next(self: *LineIterator) ?Line {
        if (self.pos > self.txt.len) return null;

        const start = self.pos;
        var i = start;
        var width: f32 = 0;
        var last_space: ?usize = null;
        var width_before_space: f32 = 0;

        while (i < self.txt.len) {
            const ch = self.txt[i];
            if (ch == '\n') {
                self.pos = i+1;
                return .{ .text = self.txt[start..i], .width = width };
            }

            const adv = self.advance(ch);
            if (ch == ' ') {
                last_space = i;
                width_before_space = width;
                width += adv;
                i += 1;

                continue;
            }

            if (self.max_width) |mw| {
                if (width+adv > mw + 0.001 and i > start) {
                    if (last_space) |s| {
                        self.pos = s+1;
                        return .{ .text = self.txt[start..s], .width = width_before_space };
                    }

                    self.pos = i;
                    return .{ .text = self.txt[start..i], .width = width };
                }
            }

            width += adv;
            i += 1;
        }

        self.pos = self.txt.len+1;
        return .{ .text = self.txt[start..], .width = width };
    }
};

pub fn lineHeight(atlas: *const FontAtlas, size: f32) f32 {
    const scale = atlas.calculateScale(size);
    return (atlas.ascent + atlas.descent + atlas.line_gap) * scale;
}

pub fn ascent(atlas: *const FontAtlas, size: f32) f32 {
    const scale = atlas.calculateScale(size);
    return (atlas.ascent + atlas.line_gap/2) * scale;
}

pub fn measureText(atlas: *const FontAtlas, txt: []const u8, size: f32, max_width: ?f32) math.Vec2 {
    if (txt.len == 0) return .zero;

    var iter: LineIterator = .init(atlas, txt, size, max_width);
    var widest: f32 = 0;
    var lines: f32 = 0;

    while (iter.next()) |l| : (lines += 1) widest = @max(widest, l.width);
    return .new(
        widest,
        lines * lineHeight(atlas, size)
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
    const line_h = lineHeight(atlas, t.size);
    const asc = ascent(atlas, t.size);

    const max_w: ?f32 = if (t.wrap) size.x else null;
    const block_h = measureText(atlas, t.content, t.size, max_w).y;

    const top_y = switch (t.justify) {
        .start => origin.y,
        .center => origin.y + (size.y - block_h) / 2,
        .end, .space_between => origin.y + size.y - block_h,
    };

    var quads: std.ArrayList(GlyphQuad) = .empty;
    errdefer quads.deinit(allocator);

    var iter: LineIterator = .init(atlas, t.content, t.size, max_w);
    var line_idx: f32 = 0;
    while (iter.next()) |l| : (line_idx += 1) {
        const baseline = @round(top_y + asc + line_idx * line_h);
        var cur_x = switch (t.align_text) {
            .start => origin.x,
            .center => origin.x + (size.x - l.width) / 2,
            .end => origin.x + size.x - l.width,
        };

        for (l.text) |ch| {
            if (ch < 32 or ch > 126) continue;
            const glyph = atlas.glyphs.get(ch) orelse continue;

            try quads.append(allocator, .{
                .pos = .{ cur_x + glyph.bearing[0] * scale, baseline - glyph.bearing[1] * scale },
                .size = .{ glyph.size[0] * scale, glyph.size[1] * scale },
                .uv_pos = glyph.uv_pos,
                .uv_size = glyph.uv_size,
            });
            cur_x += glyph.advance * scale;
        }
    }

    return quads.toOwnedSlice(allocator);
}