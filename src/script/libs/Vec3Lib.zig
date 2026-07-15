// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Vec3 = @import("../objects/Vec3.zig").Vec3;

pub const Vec3Lib = struct {
    pub const name = "Vec3";

    pub fn init() Vec3Lib { return .{}; }

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3.init(x, y, z);
    }
};
