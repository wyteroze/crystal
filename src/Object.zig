// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("types.zig");

const Mesh = @import("Mesh.zig").Mesh;
const Sprite = @import("Sprite.zig").Sprite;
pub const ObjectKind = enum { mesh, image };

pub const Object = struct {
    transform: types.Transform,
    data: union(ObjectKind) {
        mesh: struct {
            mesh: *const Mesh,
            texture: ?*const Sprite
        },
        image: struct {
            image: *const Sprite
        }
    }
};
