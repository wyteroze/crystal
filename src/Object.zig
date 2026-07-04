// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("types.zig");

const Mesh = @import("Mesh.zig").Mesh;
const Sprite = @import("Sprite.zig").Sprite;
const Camera = @import("Camera.zig").Camera;
pub const ObjectKind = enum { mesh, image, camera };

pub const Object = struct {
    transform: types.Transform,
    data: union(ObjectKind) {
        mesh: MeshObject,
        image: ImageObject,
        camera: CameraObject,

        pub fn luaName(self: @This()) []const u8 {
            return switch (self) {
                .mesh => "Mesh",
                .image => "Image",
                .camera => "Camera"
            };
        }
    }
};

pub const MeshObject = struct {
    mesh: *const Mesh,
    texture: ?*const Sprite,
    mesh_ref: i32,
    texture_ref: ?i32 = null
};

pub const ImageObject = struct {
    image: *const Sprite,
    image_ref: i32,
};

pub const CameraObject = struct {
    camera: *Camera
};
