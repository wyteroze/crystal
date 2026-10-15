// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const clamp = std.math.clamp;

pub const ColorName = enum {
    AliceBlue, AntiqueWhite, Aqua, Aquamarine, Azure,
    Beige, Bisque, Black, BlanchedAlmond, Blue, BlueViolet, Brown, BurlyWood,
    CadetBlue, Chartreuse, Chocolate, Coral, CornflowerBlue, Cornsilk, Crimson, Cyan,
    DarkBlue, DarkCyan, DarkGoldenrod, DarkGray, DarkGreen, DarkGrey, DarkKhaki, DarkMagenta, DarkOliveGreen, DarkOrange, DarkOrchid, DarkRed, DarkSalmon, DarkSeaGreen, DarkSlateBlue, DarkSlateGray, DarkSlateGrey, DarkTurquoise, DarkViolet, DeepPink, DeepSkyBlue, DimGray, DimGrey, DodgerBlue,
    Firebrick, FloralWhite, ForestGreen, Fuchsia,
    Gainsboro, GhostWhite, Gold, Goldenrod, Gray, Green, GreenYellow, Grey,
    Honeydew, HotPink,
    IndianRed, Indigo, Ivory,
    Khaki,
    Lavender, LavenderBlush, LawnGreen, LemonChiffon, LightBlue, LightCoral, LightCyan, LightGoldenrodYellow, LightGray, LightGreen, LightGrey, LightPink, LightSalmon, LightSeaGreen, LightSkyBlue, LightSlateGray, LightSlateGrey, LightSteelBlue, LightYellow, Lime, LimeGreen, Linen,
    Magenta, Maroon, MediumAquamarine, MediumBlue, MediumOrchid, MediumPurple, MediumSeaGreen, MediumSlateBlue, MediumSpringGreen, MediumTurquoise, MediumVioletRed, MidnightBlue, MintCream, MistyRose, Moccasin, NavajoWhite,
    Navy,
    OldLace, Olive, OliveDrab, Orange, OrangeRed, Orchid,
    PaleGoldenrod, PaleGreen, PaleTurquoise, PaleVioletRed, PapayaWhip, PeachPuff, Peru, Pink, Plum, PowderBlue, Purple,
    RebeccaPurple,
    Red, RosyBrown, RoyalBlue,
    SaddleBrown, Salmon, SandyBrown, SeaGreen, Seashell, Sienna, Silver, SkyBlue, SlateBlue, SlateGray, SlateGrey, Snow, SpringGreen, SteelBlue,
    Tan, Teal, Thistle, Tomato, Turquoise,
    Violet,
    Wheat, White, WhiteSmoke,
    Yellow, YellowGreen,

    pub fn getHex(self: ColorName) u32 {
        return switch (self) {
            .AliceBlue => 0xF0F8FF, .AntiqueWhite => 0xFAEBD7, .Aqua => 0x00FFFF, .Aquamarine => 0x7FFFD4, .Azure => 0xF0FFFF,
            .Beige => 0xF5F5DC, .Bisque => 0xFFE4C4, .Black => 0x000000, .BlanchedAlmond => 0xFFEBCD, .Blue => 0x0000FF, .BlueViolet => 0x8A2BE2, .Brown => 0xA52A2A, .BurlyWood => 0xDEB887,
            .CadetBlue => 0x5F9EA0, .Chartreuse => 0x7FFF00, .Chocolate => 0xD2691E, .Coral => 0xFF7F50, .CornflowerBlue => 0x6495ED, .Cornsilk => 0xFFF8DC, .Crimson => 0xDC143C, .Cyan => 0x00FFFF,
            .DarkBlue => 0x00008B, .DarkCyan => 0x008B8B, .DarkGoldenrod => 0xB8860B, .DarkGray => 0xA9A9A9, .DarkGreen => 0x006400, .DarkGrey => 0xA9A9A9, .DarkKhaki => 0xBDB76B, .DarkMagenta => 0x8B008B, .DarkOliveGreen => 0x556B2F, .DarkOrange => 0xFF8C00, .DarkOrchid => 0x9932CC, .DarkRed => 0x8B0000, 
            .DarkSalmon => 0xE9967A, .DarkSeaGreen => 0x8FBC8F, .DarkSlateBlue => 0x483D8B, .DarkSlateGray => 0x2F4F4F, .DarkSlateGrey => 0x2F4F4F, .DarkTurquoise => 0x00CED1, .DarkViolet => 0x9400D3, .DeepPink => 0xFF1493, .DeepSkyBlue => 0x00BFFF, .DimGray => 0x696969, .DimGrey => 0x696969, .DodgerBlue => 0x1E90FF,
            .Firebrick => 0xB22222, .FloralWhite => 0xFFFAF0, .ForestGreen => 0x228B22, .Fuchsia => 0xFF00FF,
            .Gainsboro => 0xDCDCDC, .GhostWhite => 0xF8F8FF, .Gold => 0xFFD700, .Goldenrod => 0xDAA520, .Gray => 0x808080, .Green => 0x008000, .GreenYellow => 0xADFF2F, .Grey => 0x808080,
            .Honeydew => 0xF0FFF0, .HotPink => 0xFF69B4,
            .IndianRed => 0xCD5C5C, .Indigo => 0x4B0082, .Ivory => 0xFFFFF0,
            .Khaki => 0xF0E68C,
            .Lavender => 0xE6E6FA, .LavenderBlush => 0xFFF0F5, .LawnGreen => 0x7CFC00, .LemonChiffon => 0xFFFACD, .LightBlue => 0xADD8E6, .LightCoral => 0xF08080, .LightCyan => 0xE0FFFF, .LightGoldenrodYellow => 0xFAFAD2, .LightGray => 0xD3D3D3, .LightGreen => 0x90EE90, .LightGrey => 0xD3D3D3, 
            .LightPink => 0xFFB6C1, .LightSalmon => 0xFFA07A, .LightSeaGreen => 0x20B2AA, .LightSkyBlue => 0x87CEFA, .LightSlateGray => 0x778899, .LightSlateGrey => 0x778899, .LightSteelBlue => 0xB0C4DE, .LightYellow => 0xFFFFE0, .Lime => 0x00FF00, .LimeGreen => 0x32CD32, .Linen => 0xFAF0E6,
            .Magenta => 0xFF00FF, .Maroon => 0x800000, .MediumAquamarine => 0x66CDAA, .MediumBlue => 0x0000CD, .MediumOrchid => 0xBA55D3, .MediumPurple => 0x9370DB, .MediumSeaGreen => 0x3CB371, .MediumSlateBlue => 0x7B68EE, 
            .MediumSpringGreen => 0x00FA9A, .MediumTurquoise => 0x48D1CC, .MediumVioletRed => 0xC71585, .MidnightBlue => 0x191970, .MintCream => 0xF5FFFA, .MistyRose => 0xFFE4E1, .Moccasin => 0xFFE4B5,
            .NavajoWhite => 0xFFDEAD, .Navy => 0x000080,
            .OldLace => 0xFDF5E6, .Olive => 0x808000, .OliveDrab => 0x6B8E23, .Orange => 0xFFA500, .OrangeRed => 0xFF4500, .Orchid => 0xDA70D6,
            .PaleGoldenrod => 0xEEE8AA, .PaleGreen => 0x98FB98, .PaleTurquoise => 0xAFEEEE, .PaleVioletRed => 0xDB7093, .PapayaWhip => 0xFFEFD5, .PeachPuff => 0xFFDAB9, .Peru => 0xCD853F, .Pink => 0xFFC0CB, .Plum => 0xDDA0DD, .PowderBlue => 0xB0E0E6,
            .Purple => 0x800080,
            .RebeccaPurple => 0x663399, .Red => 0xFF0000,
            .RosyBrown => 0xBC8F8F, .RoyalBlue => 0x4169E1,
            .SaddleBrown => 0x8B4513, .Salmon => 0xFA8072, .SandyBrown => 0xF4A460, .SeaGreen => 0x2E8B57, .Seashell => 0xFFF5EE, .Sienna => 0xA0522D, .Silver => 0xC0C0C0, .SkyBlue => 0x87CEEB, .SlateBlue => 0x6A5ACD, .SlateGray => 0x708090, .SlateGrey => 0x708090, .Snow => 0xFFFAFA, .SpringGreen => 0x00FF7F, .SteelBlue => 0x4682B4,
            .Tan => 0xD2B48C, .Teal => 0x008080, .Thistle => 0xD8BFD8, .Tomato => 0xFF6347, .Turquoise => 0x40E0D0,
            .Violet => 0xEE82EE,
            .Wheat => 0xF5DEB3, .White => 0xFFFFFF, .WhiteSmoke => 0xF5F5F5,
            .Yellow => 0xFFFF00, .YellowGreen => 0x9ACD32,
        };
    }
};

const Color = @This();
r: f32 = 1,
g: f32 = 1,
b: f32 = 1,
a: f32 = 1,

pub fn fromRgb(rc: u8, gc: u8, bc: u8, ac: u8) Color {
    return .{
        .r = @as(f32, @floatFromInt(rc)) / 255.0,
        .g = @as(f32, @floatFromInt(gc)) / 255.0,
        .b = @as(f32, @floatFromInt(bc)) / 255.0,
        .a = @as(f32, @floatFromInt(ac)) / 255.0
    };
}

pub fn toRgb(self: Color) struct { u8, u8, u8, u8 } {
    return .{ 
        @trunc(clamp(self.r * 255.0, 0.0, 255.0)), 
        @trunc(clamp(self.g * 255.0, 0.0, 255.0)), 
        @trunc(clamp(self.b * 255.0, 0.0, 255.0)), 
        @trunc(clamp(self.a * 255.0, 0.0, 255.0))
    };
}

pub fn fromRgbFloat(rc: f32, gc: f32, bc: f32, ac: ?f32) Color {
    return .{ 
        .r = clamp(rc, 0.0, 1.0), 
        .g = clamp(gc, 0.0, 1.0), 
        .b = clamp(bc, 0.0, 1.0), 
        .a = clamp(ac orelse 1.0, 0.0, 1.0)
    };
}

pub fn fromHsv(h: f32, s: f32, v: f32, a: ?f32) Color {
    const sc = std.math.clamp(s, 0.0, 1.0);
    const vc = std.math.clamp(v, 0.0, 1.0);

    const sector = @mod(h, 1.0) * 6.0;
    const c = vc * sc;
    const x = c * (1.0 - @abs(@mod(sector, 2.0) - 1.0));
    const m = vc - c;

    const rgb = switch (@min(@as(u32, @trunc(sector)), 5)) {
        0 => .{ c, x, 0.0 },
        1 => .{ x, c, 0.0 },
        2 => .{ 0.0, c, x },
        3 => .{ 0.0, x, c },
        4 => .{ x, 0.0, c },
        else => .{ c, 0.0, x },
    };

    return .{
        .r = rgb[0] + m,
        .g = rgb[1] + m,
        .b = rgb[2] + m,
        .a = clamp(a orelse 1.0, 0.0, 1.0),
    };
}

pub fn toHsv(self: Color) struct { f32, f32, f32, f32 } {
    const max = @max(self.r, @max(self.g, self.b));
    const min = @min(self.r, @min(self.g, self.b));
    const delta = max - min;

    var h: f32 = 0.0;
    if (delta > 0.0) {
        h = (1.0 / 6.0) * if (max == self.r) @mod((self.g - self.b) / delta, 6.0)
        else if (max == self.g) (self.b - self.r) / delta + 2.0
        else (self.r - self.g) / delta + 4.0;
    }

    const s: f32 = if (max > 0.0) delta / max else 0.0;
    return .{ h, s, max, self.a };
}

pub fn fromHex(hex: u32) Color {
    const rc: u8 = @intCast((hex >> 24) & 0xFF);
    const gc: u8 = @intCast((hex >> 16) & 0xFF);
    const bc: u8 = @intCast((hex >> 8) & 0xFF);
    const ac: u8 = @intCast(hex & 0xFF);

    return fromRgb(rc, gc, bc, ac);
}

pub fn fromName(name: ColorName, alpha: ?f32) Color {
    const a_int: u32 = @trunc(clamp((alpha orelse 1.0) * 255.0, 0.0, 255.0));
    return fromHex((name.getHex() << 8) | a_int);
}

pub fn toHex(self: Color) u32 {
    const r, const g, const b, const a = toRgb(self);

    return (@as(u32, r) << 24) |
           (@as(u32, g) << 16) |
           (@as(u32, b) << 8)  |
            @as(u32, a);
}

pub fn toArr(self: Color) [4]f32 { return .{ self.r, self.g, self.b, self.a }; }
pub fn fromArr(arr: [4]f32) Color { return .{ .r = arr[0], .g = arr[1], .b = arr[2], .a = arr[3] }; }

pub fn srgbEncode(self: Color) Color {
    return .{
        .r = srgbEncodeChannel(self.r),
        .g = srgbEncodeChannel(self.g),
        .b = srgbEncodeChannel(self.b),
        .a = self.a
    };
}

pub fn srgbDecode(self: Color) Color {
    return .{
        .r = srgbDecodeChannel(self.r),
        .g = srgbDecodeChannel(self.g),
        .b = srgbDecodeChannel(self.b),
        .a = self.a
    };
}

pub fn lerp(self: Color, other: Color, t: f32) Color {
    return .{
        .r = std.math.lerp(self.r, other.r, t),
        .g = std.math.lerp(self.g, other.g, t),
        .b = std.math.lerp(self.b, other.b, t),
        .a = std.math.lerp(self.a, other.a, t)
    };
}

pub fn withAlpha(self: Color, alpha: f32) Color {
    return .{ .r = self.r, .g = self.g, .b = self.b, .a = alpha };
}

pub fn eql(self: Color, other: Color) bool {
    return self.r == other.r
        and self.g == other.g
        and self.b == other.b
        and self.a == other.a;
}

fn srgbEncodeChannel(c: f32) f32 {
    if (c <= 0.0031308) return c * 12.92;
    return @floatCast(1.055 * std.math.pow(f32, c, 1.0 / 2.4) - 0.055);
}

fn srgbDecodeChannel(c: f32) f32 {
    if (c <= 0.04045) return c / 12.92;
    return @floatCast(std.math.pow(f32, (c + 0.055) / 1.055, 2.4));
}

pub fn format(
    self: @This(),
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try writer.print("Color({d}, {d}, {d}, {d})", .{ self.r, self.g, self.b, self.a });
}

const bind = @import("../scripting/bind/bind.zig");
pub const api = bind.value(Color, .{
    .name = "Color",
    .fields = &.{ "r", "g", "b", "a" },
    .methods = &.{
        bind.func("Lerp", Color.lerp),
        bind.func("ToRGBA", Color.toRgb),
        bind.func("ToHSVA", Color.toHsv),
        // bind.func("ToHex", struct {}.c)
    },
    .statics = &.{
        bind.func("new", Color.fromRgbFloat),
        bind.func("fromName", Color.fromName),
        bind.func("fromHSV", Color.fromHsv),
        //bind.func("fromHex", Color.fromHexString)
    },
    .ops = .{ .tostring = .auto }
});