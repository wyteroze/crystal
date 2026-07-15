// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Vec3_SIMD = @import("../../types.zig").Vec3_SIMD;
const shared = @import("../shared.zig");

pub const Vec3 = struct {
    pub const name = "Vec3Object";
    pub const hidden = .{ "vec" };
    pub const operators = .{
        .add = "add",
        .sub = "sub",
        .mul = "mul",
        .div = "div",
        .unm = "unm"
    };

    vec: Vec3_SIMD,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .vec = Vec3_SIMD{ x, y, z } };
    }

    pub fn getX(self: Vec3) f32 { return self.vec[0]; }
    pub fn setX(self: *Vec3, v: f32) void { self.vec[0] = v; }
    pub fn getY(self: Vec3) f32 { return self.vec[1]; }
    pub fn setY(self: *Vec3, v: f32) void { self.vec[1] = v; }
    pub fn getZ(self: Vec3) f32 { return self.vec[2]; }
    pub fn setZ(self: *Vec3, v: f32) void { self.vec[2] = v; }

    pub fn add(self: Vec3, other: Vec3) Vec3 { return .{ .vec = self.vec + other.vec }; }
    pub fn sub(self: Vec3, other: Vec3) Vec3 { return .{ .vec = self.vec - other.vec }; }
    pub fn mul(self: Vec3, other: Vec3) Vec3 { return .{ .vec = self.vec * other.vec }; }
    pub fn div(self: Vec3, other: Vec3) Vec3 { return .{ .vec = self.vec / other.vec }; }
    pub fn unm(self: Vec3) Vec3 { return .{ .vec = -self.vec }; }

    pub fn format(self: Vec3, writer: *std.Io.Writer) !void {
        try writer.print("({d}, {d}, {d})", .{
            shared.cleanFloatingPoint(self.vec[0]),
            shared.cleanFloatingPoint(self.vec[1]),
            shared.cleanFloatingPoint(self.vec[2]),
        });
    }
};
