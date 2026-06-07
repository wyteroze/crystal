// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("types.zig");
const math = @import("math.zig");

const Mat4 = types.Mat4;
const Transform = types.Transform;
const Vec3_SIMD = types.Vec3_SIMD;
const Vec4_SIMD = types.Vec4_SIMD;

pub const Camera = struct {
    nearPlane: f32,
    farPlane: f32,
    fov: f32,
    aspectRatio: f32,
    transform: Transform,

    pub fn init(nearPlane: f32, farPlane: f32, fov: f32, aspectRatio: f32) Camera {
        return .{
            .nearPlane = nearPlane,
            .farPlane = farPlane,
            .fov = fov,
            .aspectRatio = aspectRatio,
            .transform = Transform.identity()
        };
    }

    pub fn getProjectionMatrix(self: Camera) Mat4 {
        const fov_rad = 1.0 / @tan((self.fov / 180.0 * std.math.pi)/2);

        return .{ .rows = .{
            Vec4_SIMD{ self.aspectRatio * fov_rad, 0, 0, 0 },
            Vec4_SIMD{ 0, fov_rad, 0, 0 },
            Vec4_SIMD{ 0, 0, self.farPlane / (self.farPlane - self.nearPlane), 1.0 },
            Vec4_SIMD{ 0, 0, (-self.farPlane * self.nearPlane) / (self.farPlane - self.nearPlane), 0 }
        }};
    }

    pub fn getLookDirection(self: Camera) Vec3_SIMD {
        const pitch = self.transform.rotation[0] * (std.math.pi / 180.0);
        const yaw = self.transform.rotation[1] * (std.math.pi / 180.0);
        const look_dir = Vec3_SIMD{
            @sin(yaw) * @cos(pitch),
            -@sin(pitch),
            @cos(yaw) * @cos(pitch)
        };

        return look_dir;
    }

    pub fn getRightDirection(self: Camera) Vec3_SIMD {
        const yaw = self.transform.rotation[1] * (std.math.pi / 180.0);
        const look_dir = Vec3_SIMD{
            @cos(yaw),
            0,
            -@sin(yaw)
        };

        return look_dir;
    }

    pub fn getUpDirection(self: Camera) Vec3_SIMD {
        const up = math.cross(
            self.getLookDirection(),
            self.getRightDirection()
        );

        return up;
    }

    pub fn getViewMatrix(self: Camera) Mat4 {
        const up = Vec3_SIMD{ 0.0, 1.0, 0.0 };
        const look_dir = self.getLookDirection();

        const target = self.transform.position + look_dir;
        const camera_matrix = math.pointAt(self.transform.position, target, up);

        return math.matrixQuickInverse(camera_matrix);
    }
};
