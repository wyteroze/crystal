// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

// Engine/scripting types

pub const Vec3 = struct { x: f32, y: f32, z: f32 };
pub const Mat4 = struct { data: [16]f32 };
pub const Size2D = struct { width: u32, height: u32 };
pub const Color3RGB = struct { r: u8, g: u8, b: u8 };
pub const Transform = struct {
    position: @Vector(3, f32) = @Vector(3, f32){ 0, 0, 0 },
    rotation: @Vector(3, f32) = @Vector(3, f32){ 0, 0, 0 },
    scale: @Vector(3, f32) = @Vector(3, f32){ 1, 1, 1 }
};

// Internal types

pub const Vec2_i32 = struct { x: i32, y: i32 };
pub const Vec2_u32 = struct { x: u32, y: u32 };
pub const Vec2_f32 = struct { x: f32, y: f32 };
pub const Vec3_u32 = struct { x: u32, y: u32, z: u32 };

pub const Face = struct { start: u32, count: u32 };
