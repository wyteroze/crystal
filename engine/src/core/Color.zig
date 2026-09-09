// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

const Color = @This();
data: [4]f32,

pub fn fromRgb(rc: u8, gc: u8, bc: u8, ac: u8) Color {
    return .{ .data = .{
        @as(f32, @floatFromInt(rc)) / 255.0,
        @as(f32, @floatFromInt(gc)) / 255.0,
        @as(f32, @floatFromInt(bc)) / 255.0,
        @as(f32, @floatFromInt(ac)) / 255.0
    } };
}

pub fn fromRgbFloat(rc: f32, gc: f32, bc: f32, ac: f32) Color {
    return .{ .data = .{ rc, gc, bc, ac } };
}

pub fn fromHex(hex: u32) Color {
    const rc: u8 = @intCast((hex >> 24) & 0xFF);
    const gc: u8 = @intCast((hex >> 16) & 0xFF);
    const bc: u8 = @intCast((hex >> 8) & 0xFF);
    const ac: u8 = @intCast(hex & 0xFF);

    return fromRgb(rc, gc, bc, ac);
}

pub fn r(self: Color) f32 {
    return self.data[0];
}

pub fn g(self: Color) f32 {
    return self.data[1];
}

pub fn b(self: Color) f32 {
    return self.data[2];
}

pub fn a(self: Color) f32 {
    return self.data[3];
}

pub fn srgbEncode(self: Color) Color {
    return .{ .data = .{
        srgbEncodeChannel(self.data[0]),
        srgbEncodeChannel(self.data[1]),
        srgbEncodeChannel(self.data[2]),
        self.data[3]
    } };
}

pub fn srgbDecode(self: Color) Color {
    return .{ .data = .{
        srgbDecodeChannel(self.data[0]),
        srgbDecodeChannel(self.data[1]),
        srgbDecodeChannel(self.data[2]),
        self.data[3]
    } };
}

pub fn lerp(self: Color, other: Color, t: f32) Color {
    return .{ .data = .{
        self.data[0] + (other.data[0] - self.data[0]) * t,
        self.data[1] + (other.data[1] - self.data[1]) * t,
        self.data[2] + (other.data[2] - self.data[2]) * t,
        self.data[3] + (other.data[3] - self.data[3]) * t
    } };
}

pub fn withAlpha(self: Color, alpha: f32) Color {
    return .{ .data = .{ self.data[0], self.data[1], self.data[2], alpha } };
}

pub fn eql(self: Color, other: Color) bool {
    return std.mem.eql(f32, &self.data, &other.data);
}

fn srgbEncodeChannel(c: f32) f32 {
    if (c <= 0.0031308) return c * 12.92;
    return @floatCast(1.055 * std.math.pow(f32, c, 1.0 / 2.4) - 0.055);
}

fn srgbDecodeChannel(c: f32) f32 {
    if (c <= 0.04045) return c / 12.92;
    return @floatCast(std.math.pow(f32, (c + 0.055) / 1.055, 2.4));
}