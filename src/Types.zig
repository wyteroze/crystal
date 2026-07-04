// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

// Basic types
pub const Vec3 = struct { x: f32, y: f32, z: f32 };
pub const Vec2 = struct { x: f32, y: f32 };

// Internal types
pub const Vec2_u16 = struct { x: u16, y: u16 };
pub const Vec2_u32 = struct { x: u32, y: u32 };
pub const Vec4_SIMD = @Vector(4, f32);
pub const Vec3_SIMD = @Vector(3, f32);
pub const Vec2_SIMD = @Vector(2, f32);
pub const Face = struct {
    start: usize, // index into indices
    length: usize
};

pub const Vertex = struct {
    position: Vec3_SIMD,
    uv: Vec2_SIMD
};

pub const Triangle = struct {
    pa: Vertex,
    pb: Vertex,
    pc: Vertex,
    color: u32, // 0x_AA_RR_GG_BB
    depth: f32
};

pub const Mat4 = struct {
    rows: [4]Vec4_SIMD,

    pub fn initZero() Mat4 {
        return .{ .rows = .{ @splat(0), @splat(0), @splat(0), @splat(0) } };
    }
};

pub const Transform = struct {
    scale: Vec3_SIMD,
    position: Vec3_SIMD,
    rotation: Vec3_SIMD,

    pub fn zero() Transform {
        return .{
            .scale = Vec3_SIMD{ 0, 0, 0 },
            .position = Vec3_SIMD{ 0, 0, 0 },
            .rotation = Vec3_SIMD{ 0, 0, 0 },
        };
    }

    pub fn identity() Transform {
        return .{
            .scale = Vec3_SIMD{ 1, 1, 1 },
            .position = Vec3_SIMD{ 0, 0, 0 },
            .rotation = Vec3_SIMD{ 0, 0, 0 },
        };
    }
};
