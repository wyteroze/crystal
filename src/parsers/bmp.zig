// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
const std = @import("std");
const types = @import("../types.zig");
const Sprite = @import("../Sprite.zig").Sprite;

pub const ParseError = error{
    InvalidMagic,
    InvalidDimensions,
    UnexpectedEof,
    UnsupportedCompression,
    UnsupportedDibHeader,
    UnsupportedBitDepth,
};

/// VERY simple. Does not support indexed color, compression, non-standard dib headers.
pub fn parseBmp(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Sprite {
    var file_header: [14]u8 = undefined;
    reader.readSliceAll(&file_header)
        catch return ParseError.UnexpectedEof;

    if (!std.mem.eql(u8, file_header[0..2], "BM"))
        return ParseError.InvalidMagic;

    const pixel_offset = std.mem.readInt(u32, file_header[10..14], .little);

    // dib header
    // first 4 bytes are size
    var dib_size_buf: [4]u8 = undefined;
    reader.readSliceAll(&dib_size_buf)
        catch return ParseError.UnexpectedEof;
    const dib_size = std.mem.readInt(u32, &dib_size_buf, .little);

    if (dib_size != 40)
        return ParseError.UnsupportedDibHeader;

    var dib_rest: [36]u8 = undefined;
    reader.readSliceAll(&dib_rest)
        catch return ParseError.UnexpectedEof;

    const width       = std.mem.readInt(i32, dib_rest[0..4],   .little);
    const height      = std.mem.readInt(i32, dib_rest[4..8],   .little);
    const bpp         = std.mem.readInt(u16, dib_rest[10..12], .little);
    const compression = std.mem.readInt(u32, dib_rest[12..16], .little);

    if (width <= 0 or width > 65535)
        return ParseError.InvalidDimensions;
    if (height == 0 or height < -65535 or height > 65535)
        return ParseError.InvalidDimensions;
    if (bpp != 24 and bpp != 32)
        return ParseError.UnsupportedBitDepth;
    if (compression != 0)
        return ParseError.UnsupportedCompression;

    const img_width  = @as(u32, @intCast(width));
    const img_height = @as(u32, @intCast(if (height < 0) -height else height));
    const top_down   = height < 0;

    // skip to pixel data
    const bytes_read: u32 = 54;
    if (pixel_offset < bytes_read)
        return ParseError.InvalidDimensions;
    const skip = pixel_offset - bytes_read;

    reader.discardAll(skip) catch return ParseError.UnexpectedEof;

    // read pixels
    const bytes_per_pixel = @as(u32, bpp / 8);
    const row_stride = (img_width * bytes_per_pixel + 3) & ~@as(u32, 3);

    const pixels = try allocator.alloc(u32, img_width * img_height);
    errdefer allocator.free(pixels);

    const row_buf = try allocator.alloc(u8, row_stride);
    defer allocator.free(row_buf);

    for (0..img_height) |row_idx| {
        reader.readSliceAll(row_buf) catch return ParseError.UnexpectedEof;

        const dst_row = @as(u32,
            if (top_down) @intCast(row_idx)
            else img_height - 1 - @as(u32, @intCast(row_idx))
        );
        const dst_start = dst_row * img_width;

        for (0..img_width) |col| {
            const src = col * bytes_per_pixel;
            const dst = dst_start + col;
            const r = @as(u32, row_buf[src + 2]);
            const g = @as(u32, row_buf[src + 1]);
            const b = @as(u32, row_buf[src + 0]);
            const a = @as(u32, if (bytes_per_pixel == 4) row_buf[src + 3] else 0xFF);
            pixels[dst] = (a << 24) | (r << 16) | (g << 8) | b;
        }
    }

    return Sprite{
        .width  = img_width,
        .height = img_height,
        .pixels = pixels,
    };
}
