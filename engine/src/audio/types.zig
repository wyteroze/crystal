// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const math = @import("../core/math/math.zig");

pub const AudioListener = struct {
    position: math.Vec3 = .zero,
    right: math.Vec3 = .new(1, 0, 0)
};

pub const Attenuation = union(enum) {
    linear,
    exponential,
    inverse_square,
    custom: *const fn(f32) f32,
};