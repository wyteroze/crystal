// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../../gpu/gpu.zig");
const Assets = @import("../../assets/Assets.zig");

pub const GlyphInfo = struct {
    uv_pos: [2]f32,
    uv_size: [2]f32,
    size: [2]f32,
    bearing: [2]f32,
    advance: f32
};

// This is also in font_freetype.zig, so change it there too if needed.
const sdf_raster_size: u32 = 128;

const FontAtlas = @This();
texture: gpu.GpuDevice.GpuImage,
sampler: gpu.GpuDevice.GpuSampler,
glyphs: std.AutoHashMap(u32, GlyphInfo),
atlas_size: [2]u32,
white_uv: [2]f32,
raster_size: u32,

pub fn deinit(self: FontAtlas) void {
    self.texture.deinit();
    self.sampler.deinit();
    // Sorry..
    @constCast(&self.glyphs).deinit();
}

pub fn bake(allocator: std.mem.Allocator, name: [:0]const u8, device: *gpu.GpuDevice, font: Assets.types.Font) !FontAtlas {
    var max_w: u32 = 0;
    var max_h: u32 = 0;
    for (font.glyphs) |g| {
        max_w = @max(max_w, g.size[0]);
        max_h = @max(max_h, g.size[1]);
    }
    const cell_w = max_w + 2;
    const cell_h = max_h + 2;
    const cols: u32 = 16;
    const rows: u32 = (@as(u32, @intCast(font.glyphs.len)) + cols - 1) / cols;
    const atlas_w = cols * cell_w;
    const atlas_h = rows * cell_h + cell_h; // Extra cell for white pixel used in the fragment shader

    var pixels = try allocator.alloc(u8, atlas_w * atlas_h);
    defer allocator.free(pixels);
    @memset(pixels, 0);

    // aforementioned white pixel cell
    const white_x = 0;
    const white_y = rows * cell_h;
    pixels[white_y * atlas_w + white_x] = 255;

    var glyphs: std.AutoHashMap(u32, GlyphInfo) = .init(allocator);
    for (font.glyphs, 0..) |g, i| {
        const col = i % cols;
        const row = i / cols;
        // mooo
        const ox = col * cell_w;
        const oy = row * cell_h;

        for (0..g.size[1]) |y| {
            const src_row = g.pixels[(y * g.size[0])..][0..g.size[0]];
            const dst_row = pixels[((oy + y) * atlas_w + ox)..][0..g.size[0]];
            @memcpy(dst_row, src_row);
        }

        try glyphs.put(g.codepoint, .{
            .uv_pos = .{ @as(f32, @floatFromInt(ox)) / @as(f32, @floatFromInt(atlas_w)), @as(f32, @floatFromInt(oy)) / @as(f32, @floatFromInt(atlas_h)) },
            .uv_size = .{ @as(f32, @floatFromInt(g.size[0])) / @as(f32, @floatFromInt(atlas_w)), @as(f32, @floatFromInt(g.size[1])) / @as(f32, @floatFromInt(atlas_h)) },
            .size = .{ @floatFromInt(g.size[0]), @floatFromInt(g.size[1]) },
            .bearing = .{ @floatFromInt(g.bearing[0]), @floatFromInt(g.bearing[1]) },
            .advance = g.advance
        });
    }

    const white_uv_pos: [2]f32 = .{ 0, @as(f32, @floatFromInt(white_y)) / @as(f32, @floatFromInt(atlas_h)) };

    const texture = try device.createImage(.{
        .name = name,
        .width = atlas_w,
        .height = atlas_h,
        .format = .r8_unorm,
        .data = pixels,
    });

    return .{
        .texture = texture,
        .sampler = try device.createSampler(.{}),
        .glyphs = glyphs,
        .atlas_size = .{ atlas_w, atlas_h },
        .white_uv = white_uv_pos,
        .raster_size = sdf_raster_size
    };
}