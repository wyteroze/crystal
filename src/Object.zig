// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("types.zig");

const MeshData = @import("MeshData.zig").MeshData;
const ImageData = @import("ImageData.zig").ImageData;
const Camera = @import("Camera.zig").Camera;
const Vec3 = @import("script/objects/Vec3.zig").Vec3;
pub const ObjectKind = enum { mesh, image, camera };

pub const Object = struct {
    pub const hidden = .{ "data" };
    pub const name = "ObjectInstance";
    pub const lua_ref = true;

    data: union(ObjectKind) {
        mesh: MeshObject,
        image: ImageObject,
        camera: CameraObject,

        pub fn transform(self: *@This()) *types.Transform {
            return switch (self.*) {
                .mesh => |*m| &m.transform.transform,
                .image => |*i| &i.transform.transform,
                .camera => |*c| &c.transform
            };
        }

        pub fn luaName(self: @This()) []const u8 {
            return switch (self) {
                .mesh => "Mesh",
                .image => "Image",
                .camera => "Camera"
            };
        }
    },

    pub fn getPosition(self: Object) Vec3 {
        return .{ .vec = switch (self.data) {
            .mesh => |m| m.transform.transform.position,
            .image => |i| i.transform.transform.position,
            .camera => |c| c.transform.position,
        }};
    }
    pub fn setPosition(self: *Object, value: Vec3) void {
        switch (self.data) {
            .mesh => |*m| m.transform.transform.position = value.vec,
            .image => |*i| i.transform.transform.position = value.vec,
            .camera => |*c| c.transform.position = value.vec,
        }
    }

    pub fn getRotation(self: Object) Vec3 {
        return .{ .vec = switch (self.data) {
            .mesh => |m| m.transform.transform.rotation,
            .image => |i| i.transform.transform.rotation,
            .camera => |c| c.transform.rotation,
        }};
    }

    const max_camera_pitch: f32 = 89.0;

    pub fn setRotation(self: *Object, value: Vec3) void {
        switch (self.data) {
            .mesh => |*m| m.transform.transform.rotation = value.vec,
            .image => |*i| i.transform.transform.rotation = value.vec,
            .camera => |*c| {
                var rotation = value.vec;
                rotation[0] = std.math.clamp(rotation[0], -max_camera_pitch, max_camera_pitch);
                c.transform.rotation = rotation;
            },
        }
    }

    pub fn getScale(self: Object) ?Vec3 {
        return .{ .vec = switch (self.data) {
            .mesh => |m| m.transform.scale,
            .image => |i| i.transform.scale,
            .camera => return null,
        }};
    }
    pub fn setScale(self: *Object, value: Vec3) !void {
        switch (self.data) {
            .mesh => |*m| m.transform.scale = value.vec,
            .image => |*i| i.transform.scale = value.vec,
            .camera => return error.NoScaleOnCamera,
        }
    }

    pub fn getForwardDirection(self: Object) ?Vec3 {
        return .{ .vec = switch (self.data) {
            .camera => |c| c.camera.getLookDirection(),
            else => return null,
        }};
    }
    pub fn getRightDirection(self: Object) ?Vec3 {
        return .{ .vec = switch (self.data) {
            .camera => |c| c.camera.getRightDirection(),
            else => return null,
        }};
    }
    pub fn getUpDirection(self: Object) ?Vec3 {
        return .{ .vec = switch (self.data) {
            .camera => |c| c.camera.getUpDirection(),
            else => return null,
        }};
    }
};

pub const MeshObject = struct {
    transform: types.ScaledTransform,
    mesh: *const MeshData,
    texture: ?*const ImageData,
};

pub const ImageObject = struct {
    transform: types.ScaledTransform,
    image: *const ImageData,
};

pub const CameraObject = struct {
    transform: types.Transform,
    camera: *Camera
};
