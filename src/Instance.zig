// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("Types.zig");
const Mesh = @import("Mesh.zig").Mesh;

pub const Instance = struct {
    mesh: *Mesh,
    transform: types.Transform,

    pub fn update(self: *Instance, dt: f32) void {
        self.transform.rotation[1] += dt * std.math.pi;
    }
};
