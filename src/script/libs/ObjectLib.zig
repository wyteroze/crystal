// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const MeshData = @import("../../MeshData.zig").MeshData;
const ImageData = @import("../../ImageData.zig").ImageData;
const Camera = @import("../../Camera.zig").Camera;
const object = @import("../../object.zig");
const marshal = @import("../reflect/marshal.zig");
const Handle = marshal.Handle;

pub const ObjectLib = struct {
    pub const name = "Object";

    pub fn init() ObjectLib {
        return .{};
    }

    pub fn mesh(meshData: *MeshData, textureData: ?*ImageData) !Handle(object.Object) {
        const obj = try marshal.ref_allocator.create(object.Object);
        obj.* = .{ .data = .{ .mesh = .{ .transform = .identity(), .mesh = meshData, .texture = textureData } } };

        return .{ .ptr = obj };
    }

    pub fn image(imageData: *ImageData) !Handle(object.Object) {
        const obj = try marshal.ref_allocator.create(object.Object);
        obj.* = .{ .data = .{ .image = .{ .transform = .identity(), .image = imageData } } };

        return .{ .ptr = obj };
    }

    pub fn camera() !Handle(object.Object) {
        const obj = try marshal.ref_allocator.create(object.Object);
        const cam = try marshal.ref_allocator.create(Camera);

        obj.* = .{ .data = .{ .camera = .{ .transform = .identity(), .camera = cam } } };
        cam.* = Camera.init(0.1, 1000.0, 90.0, &obj.data.camera.transform);

        return .{ .ptr = obj };
    }
};
