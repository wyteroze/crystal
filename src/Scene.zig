// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");

const Object = @import("object.zig").Object;
const MeshData = @import("MeshData.zig").MeshData;
const ImageData = @import("ImageData.zig").ImageData;
const Handle = @import("script/reflect/marshal.zig").Handle;
const Diagnostic = @import("script/shared.zig").Diagnostic;
const Callback = @import("script/shared.zig").Callback;
const AudioSource = @import("audio/AudioSource.zig").AudioSource;

pub const Scene = struct {
    pub const lua_name = "SceneObject";
    pub const hidden = .{
        "objects", "callbacks", "skybox",
        "addObject", "removeObject", "update",
        "skybox_mesh"
    };
    pub const lua_ref = true;
    pub var skybox_mesh: ?MeshData = null;
    diagnostic: Diagnostic = .{},

    allocator: std.mem.Allocator,
    objects: std.ArrayList(*Object),
    audios: std.ArrayList(*AudioSource),
    name: ?[]const u8,
    callbacks: std.ArrayList(Callback),
    skybox: MeshData,

    pub fn init(allocator: std.mem.Allocator, name: ?[]const u8) !Scene {
        return .{
            .name = if (name) |n| try allocator.dupe(u8, n) else null,
            .allocator = allocator,
            .objects = .empty,
            .callbacks = .empty,
            .audios = .empty,
            .skybox = skybox_mesh orelse return error.SkyboxNotInitialized
        };
    }

    pub fn deinit(self: *Scene) void {
        if (self.name) |n| self.allocator.free(n);
        for (self.callbacks.items) |cb| cb.deinit();

        self.callbacks.deinit(self.allocator);
        self.objects.deinit(self.allocator);
        self.audios.deinit(self.allocator);
        self.skybox.deinit();
    }

    pub fn addObject(self: *Scene, object: *Object) !void {
        try self.objects.append(self.allocator, object);
    }

    pub fn removeObject(self: *Scene, object: *const Object) void {
        for (self.objects.items, 0..) |obj, i| {
            if (obj == object) {
                _ = self.objects.swapRemove(i);
                return;
            }
        }
    }

    pub fn addAudio(self: *Scene, audio: *AudioSource) !void {
        try self.audios.append(self.allocator, audio);
    }

    pub fn removeAudio(self: *Scene, audio: *const AudioSource) void {
        for (self.audios.items, 0..) |aud, i| {
            if (aud == audio) {
                _ = self.audios.swapRemove(i);
                return;
            }
        }
    }

    pub fn update(self: *Scene, dt: f32) void {
        for (self.callbacks.items) |cb| {
            cb.call(.{dt});
        }
    }

    // lua methods

    pub fn getSkyboxTexture(self: Scene) ?Handle(ImageData) {
        return .{ .ptr = self.skybox.texture orelse return null };
    }
    pub fn setSkyboxTexture(self: *Scene, texture: Handle(ImageData)) void {
        self.skybox.texture = texture.ptr;
    }

    pub fn AddObject(self: *Scene, obj: Handle(Object)) !void { try self.addObject(obj.ptr); }
    pub fn RemoveObject(self: *Scene, obj: Handle(Object)) void { self.removeObject(obj.ptr); }

    pub fn AddAudio(self: *Scene, obj: Handle(AudioSource)) !void { try self.addAudio(obj.ptr); }
    pub fn RemoveAudio(self: *Scene, obj: Handle(AudioSource)) void { self.removeAudio(obj.ptr); }

    pub fn OnUpdate(self: *Scene, cb: Callback) !void {
        try self.callbacks.append(self.allocator, cb);
    }
};
