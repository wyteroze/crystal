// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

const Color = @This();
r: f32,
g: f32,
b: f32,
a: f32,

pub fn fromRgb(rc: u8, gc: u8, bc: u8, ac: u8) Color {
    return .{
        .r = @as(f32, @floatFromInt(rc)) / 255.0,
        .g = @as(f32, @floatFromInt(gc)) / 255.0,
        .b = @as(f32, @floatFromInt(bc)) / 255.0,
        .a = @as(f32, @floatFromInt(ac)) / 255.0
    };
}

pub fn fromRgbFloat(rc: f32, gc: f32, bc: f32, ac: f32) Color {
    return .{ .r = rc, .g = gc, .b = bc, .a = ac };
}

pub fn fromHex(hex: u32) Color {
    const rc: u8 = @intCast((hex >> 24) & 0xFF);
    const gc: u8 = @intCast((hex >> 16) & 0xFF);
    const bc: u8 = @intCast((hex >> 8) & 0xFF);
    const ac: u8 = @intCast(hex & 0xFF);

    return fromRgb(rc, gc, bc, ac);
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
        .r = self.r + (other.r - self.r) * t,
        .g = self.g + (other.g - self.g) * t,
        .b = self.b + (other.b - self.b) * t,
        .a = self.a + (other.a - self.a) * t
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

pub const __lua = .val;
pub fn format(
    self: @This(),
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try writer.print("Color({d}, {d}, {d}, {d})", .{ self.r, self.g, self.b, self.a });
}

pub const registerLua = struct {
    const zlua = @import("zlua");
    const linker = @import("../scripting/scripting.zig").linker;
    const ColorBind = linker.Binding(Color, false);

    pub fn registerLua(l: *zlua.Lua) void {
        linker.value(l, Color, .{
            .name = .{ .named = "Color" },
            .scope = .{ .module = "core" },
            .constructors = &.{
                .named("new", Color.fromRgbFloat),
                .named("fromRgb", Color.fromRgb),
                .named("fromHex", Color.fromHex),
            },
            .methods = &.{
                .named("Lerp", Color.lerp)
            },
            .fields = &.{ "r", "g", "b", "a" }
        });
    }
}.registerLua;