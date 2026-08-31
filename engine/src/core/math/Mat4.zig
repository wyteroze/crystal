// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Vec3 = @import("Vec3.zig").Vec3;
const Quat = @import("Quat.zig").Quat;

pub const Mat4 = extern struct {
    m: [4][4]f32,

    pub const identity: Mat4 = .{ .m = .{ .{ 1, 0, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 1, 0 }, .{ 0, 0, 0, 1 } } };

    pub fn mul(self: Mat4, other: Mat4) Mat4 {
        var result: Mat4 = undefined;
        inline for (0..4) |row| {
            inline for (0..4) |col| {
                var sum: f32 = 0;

                inline for (0..4) |k| sum += self.m[row][k] * other.m[k][col];
                result.m[row][col] = sum;
            }
        }

        return result;
    }

    pub fn transpose(self: Mat4) Mat4 {
        var result: Mat4 = undefined;
        inline for (0..4) |r| {
            inline for (0..4) |c| {
                result.m[c][r] = self.m[r][c];
            }
        }

        return result;
    }

    pub fn fromComponents(c: [16]f32) Mat4 {
        return .{ .m = @bitCast(c) };
    }

    pub fn fromTranslation(t: Vec3) Mat4 {
        var result = Mat4.identity;
        result.m[0][3] = t.x;
        result.m[1][3] = t.y;
        result.m[2][3] = t.z;

        return result;
    }

    pub fn fromScale(s: Vec3) Mat4 {
        var result = Mat4.identity;
        result.m[0][0] = s.x;
        result.m[1][1] = s.y;
        result.m[2][2] = s.z;

        return result;
    }

    pub fn fromTRS(translation: Vec3, rotation: Quat, scale: Vec3) Mat4 {
        const t = Mat4.fromTranslation(translation);
        const r = rotation.toMat4();
        const s = Mat4.fromScale(scale);

        return t.mul(r).mul(s);
    }

    pub fn ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        var result = Mat4.identity;
        result.m[0][0] = 2.0 / (right - left);
        result.m[1][1] = 2.0 / (top - bottom);
        result.m[2][2] = -2.0 / (far - near);
        result.m[0][3] = -(right + left) / (right - left);
        result.m[1][3] = -(top + bottom) / (top - bottom);
        result.m[2][3] = -(far + near) / (far - near);

        return result;
    }

    pub fn perspective(fov_y_radians: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / @tan(fov_y_radians * 0.5);

        return .{ .m = .{ .{ f / aspect, 0, 0, 0 }, .{ 0, f, 0, 0 }, .{ 0, 0, (far + near) / (near - far), (2 * far * near) / (near - far) }, .{ 0, 0, -1, 0 } } };
    }

    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const f = target.sub(eye).normalize();
        const s = f.cross(up).normalize();
        const u = s.cross(f);

        return .{ .m = .{ .{ s.x, s.y, s.z, -s.dot(eye) }, .{ u.x, u.y, u.z, -u.dot(eye) }, .{ -f.x, -f.y, -f.z, f.dot(eye) }, .{ 0, 0, 0, 1 } } };
    }

    // Inverse of rotation+translation matrix, no scale
    pub fn invertRT(self: Mat4) Mat4 {
        const tx = self.m[0][3];
        const ty = self.m[1][3];
        const tz = self.m[2][3];

        var result: Mat4 = .{ .m = .{ .{ self.m[0][0], self.m[1][0], self.m[2][0], 0 }, .{ self.m[0][1], self.m[1][1], self.m[2][1], 0 }, .{ self.m[0][2], self.m[1][2], self.m[2][2], 0 }, .{ 0, 0, 0, 1 } } };

        result.m[0][3] = -(result.m[0][0] * tx + result.m[0][1] * ty + result.m[0][2] * tz);
        result.m[1][3] = -(result.m[1][0] * tx + result.m[1][1] * ty + result.m[1][2] * tz);
        result.m[2][3] = -(result.m[2][0] * tx + result.m[2][1] * ty + result.m[2][2] * tz);

        return result;
    }

    pub fn components(self: Mat4) [16]f32 {
        return @bitCast(self.m);
    }

    pub const __format_len = 2048;
    pub fn format(self: Mat4, buf: []u8) []const u8 {
        const m = self.m;

        return std.fmt.bufPrint(buf,
            \\Mat4(
            \\    [{d:6.2}, {d:6.2}, {d:6.2}, {d:6.2}]
            \\    [{d:6.2}, {d:6.2}, {d:6.2}, {d:6.2}]
            \\    [{d:6.2}, {d:6.2}, {d:6.2}, {d:6.2}]
            \\    [{d:6.2}, {d:6.2}, {d:6.2}, {d:6.2}]
            \\)
        , .{
            m[0][0], m[0][1], m[0][2], m[0][3],
            m[1][0], m[1][1], m[1][2], m[1][3],
            m[2][0], m[2][1], m[2][2], m[2][3],
            m[3][0], m[3][1], m[3][2], m[3][3],
        }) catch
            \\Mat4(
            \\    [?, ?, ?, ?]
            \\    [?, ?, ?, ?]
            \\    [?, ?, ?, ?]
            \\    [?, ?, ?, ?]
            \\)
        ;
    }

    pub const __lua = .val;
};

pub fn registerLua(l: anytype) void {
    const linker = @import("../../scripting/scripting.zig").linker;

    linker.value(l, Mat4, .{ .name = .auto, .scope = .{ .module = "core.math" }, .constructors = &.{ .named("fromTranslation", Mat4.fromTranslation), .named("fromComponents", Mat4.fromComponents), .named("fromScale", Mat4.fromScale), .named("fromTRS", Mat4.fromTRS), .named("ortho", Mat4.ortho), .named("lookAt", Mat4.lookAt), .named("perspective", Mat4.perspective) }, .methods = &.{.named("Components", Mat4.components)}, .constants = &.{.named("identity", Mat4.identity)}, .ops = .{ .mul = .custom(Mat4.mul), .tostring = .format(Mat4.format) } });
}
