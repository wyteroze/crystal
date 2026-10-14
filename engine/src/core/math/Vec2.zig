// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub const Vec2 = extern struct {
    pub const Simd2 = @Vector(2, f32);
    x: f32, y: f32,

    pub const zero: Vec2 = .{ .x = 0, .y = 0 };
    pub const one: Vec2 = .{ .x = 1, .y = 1 };

    pub fn new(x: f32, y: f32) Vec2 { return .{ .x = x, .y = y }; }
    pub fn fromSimd(vec: Simd2) Vec2 { return .{ .x = vec[0], .y = vec[1] }; }
    pub fn fromArr(array: [2]f32) Vec2 { return .{ .x = array[0], .y = array[1] };  }
    pub fn simd(self: Vec2) Simd2 { return Simd2{ self.x, self.y }; }
    pub fn arr(self: Vec2) [2]f32 { return .{ self.x, self.y }; }

    pub fn add(self: Vec2, other: Vec2) Vec2 { return .fromSimd(self.simd() + other.simd()); }
    pub fn sub(self: Vec2, other: Vec2) Vec2 { return .fromSimd(self.simd() - other.simd()); }
    pub fn mul(self: Vec2, other: Vec2) Vec2 { return .fromSimd(self.simd() * other.simd()); }
    pub fn div(self: Vec2, other: Vec2) Vec2 { return .fromSimd(self.simd() / other.simd()); }
    pub fn dot(self: Vec2, other: Vec2) f32 { return @reduce(.Add, self.simd() * other.simd()); }
    pub fn lerp(self: Vec2, other: Vec2, t: f32) Vec2 { return self.add(other.sub(self).scale(t)); }
    pub fn scale(self: Vec2, s: f32) Vec2 { return .fromSimd(self.simd() * @as(Simd2, @splat(s))); }
    pub fn length(self: Vec2) f32 { return @sqrt(self.dot(self)); }

    pub fn toRadians(self: Vec2) Vec2 { return .fromSimd(self.simd() * @as(Simd2, @splat(std.math.pi / 180.0))); }
    pub fn toDegrees(self: Vec2) Vec2 { return .fromSimd(self.simd() * @as(Simd2, @splat(180.0 / std.math.pi))); }

    pub fn normalize(self: Vec2) Vec2 {
        const len = self.length();
        if (len < std.math.floatEps(f32)) return .zero;

        return self.scale(1.0 / len);
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Vec2({d:.2}, {d:.2})", .{ self.x, self.y });
    }

    pub const __lua = .val;
};

const bind = @import("../../scripting/bind/bind.zig");
pub const api = bind.value(Vec2, .{
    .name = "Vec2",
    .fields = &.{ "x", "y" },
    .statics = &.{ 
        bind.constant("zero", Vec2.zero), 
        bind.constant("one", Vec2.one),
        bind.func("new", Vec2.new),
    },
    .ops = .{ 
        .tostring = .auto, 
        .add = .{ .member = bind.func("add", Vec2.add) },
        .sub = .{ .member = bind.func("sub", Vec2.sub) },
        .mul = .{ .member = bind.func("mul", Vec2.mul) },
        .div = .{ .member = bind.func("div", Vec2.div) }
    }
});
