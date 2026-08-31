// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Vec3 = @import("Vec3.zig").Vec3;
const Mat4 = @import("Mat4.zig").Mat4;

pub const Quat = extern struct {
    const Simd4 = @Vector(4, f32);
    x: f32, y: f32, z: f32, w: f32,

    pub const identity: Quat = .{ .x = 0, .y = 0, .z = 0, .w = 1 };

    pub fn new(x: f32, y: f32, z: f32, w: f32) Quat { return .{ .x = x, .y = y, .z = z, .w = w }; }
    pub fn simd(self: Quat) Simd4 { return .{ self.x, self.y, self.z, self.w }; }
    pub fn fromSimd(v: Simd4) Quat { return .{ .x = v[0], .y = v[1], .z = v[2], .w = v[3] }; }

    // YXZ order. RADIANS!!!
    pub fn fromEuler(vec: Vec3) Quat {
        const hx = vec.x * 0.5;
        const hy = vec.y * 0.5;
        const hz = vec.z * 0.5;

        const cx = @cos(hx);
        const sx = @sin(hx);
        const cy = @cos(hy);
        const sy = @sin(hy);
        const cz = @cos(hz);
        const sz = @sin(hz);

        return .{
            .x = sx * cy * cz + cx * sy * sz,
            .y = cx * sy * cz - sx * cy * sz,
            .z = cx * cy * sz - sx * sy * cz,
            .w = cx * cy * cz + sx * sy * sz
        };
    }

    // XYZ in radians
    pub fn toEuler(q: Quat) Vec3 {
        // pitch (X)
        const sinp = 2 * (q.w * q.x - q.y * q.z);
        const pitch = if (@abs(sinp) >= 1)
            std.math.copysign(@as(f32, std.math.pi / 2.0), sinp)
        else
            std.math.asin(sinp);

        // yaw (Y)
        const siny = 2 * (q.w * q.y + q.x * q.z);
        const cosy = 1 - 2 * (q.x * q.x + q.y * q.y);
        const yaw = std.math.atan2(siny, cosy);

        // roll (Z)
        const sinr = 2 * (q.w * q.z + q.x * q.y);
        const cosr = 1 - 2 * (q.x * q.x + q.z * q.z);
        const roll = std.math.atan2(sinr, cosr);

        return .{ .x = pitch, .y = yaw, .z = roll };
    }

    pub fn fromAxisAngle(axis: Vec3, angle_radians: f32) Quat {
        const half = angle_radians * 0.5;

        const s = @sin(half);
        const n = axis.normalize();

        return .{
            .x = n.x * s,
            .y = n.y * s,
            .z = n.z * s,
            .w = @cos(half)
        };
    }

    pub fn mul(a: Quat, b: Quat) Quat {
        return .{
            .x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            .y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            .z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
            .w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
        };
    }

    pub fn normalize(a: Quat) Quat {
        const v = a.simd();
        const len = @sqrt(@reduce(.Add, v * v));
        if (len == 0) return .identity;

        return .fromSimd(v * @as(@Vector(4, f32), @splat(1.0 / len)));
    }

    pub fn toMat4(q: Quat) Mat4 {
        const xx = q.x * q.x;
        const yy = q.y * q.y;
        const zz = q.z * q.z;
        const xy = q.x * q.y;
        const xz = q.x * q.z;
        const yz = q.y * q.z;
        const wx = q.w * q.x;
        const wy = q.w * q.y;
        const wz = q.w * q.z;

        return .{ .m = .{
            .{ 1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy), 0 },
            .{ 2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx), 0 },
            .{ 2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy), 0 },
            .{ 0, 0, 0, 1 }
        } };
    }

    pub const __format_len = 128;
    pub fn format(self: Quat, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "Quat({d:.2}, {d:.2}, {d:.2}, {d:.2})", .{ self.x, self.y, self.z, self.w })
            catch "Quat(?, ?, ?, ?)";
    }

    pub const __lua = .val;
};

pub fn registerLua(l: anytype) void {
    const linker = @import("../../scripting/scripting.zig").linker;

    linker.value(l, Quat, .{
        .name = .auto,
        .scope = .{ .module = "core.math" },
        .constructors = &.{
            .named("new", Quat.new),
            .named("fromEuler", Quat.fromEuler),
            .named("fromAxisAngle", Quat.fromAxisAngle)
        },
        .methods = &.{
            .named("ToEuler", Quat.toEuler),
            .named("ToMat4", Quat.toMat4),
            .named("Normalize", Quat.normalize)
        },
        .constants = &.{
            .named("identity", Quat.identity)
        },
        .fields = &.{ "x", "y", "z", "w" },
        .ops = .{
            .mul = .custom(Quat.mul),
            .eq = .identity,
            .tostring = .format(Quat.format)
        }
    });
}
