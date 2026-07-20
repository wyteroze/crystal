// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Scene = @import("../../Scene.zig").Scene;
const SceneRegistry = @import("../../engine/SceneRegistry.zig").SceneRegistry;
const Handle = @import("../reflect/marshal.zig").Handle;
const marshal = @import("../reflect/marshal.zig");

pub const SceneLib = struct {
    pub const name = "Scene";
    pub const hidden = .{ "registry" };
    registry: *SceneRegistry,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, registry: *SceneRegistry) SceneLib {
        return .{
            .allocator = allocator,
            .registry = registry
        };
    }

    pub fn new(self: SceneLib, sceneName: []const u8) !Handle(Scene) {
        const scene = try self.allocator.create(Scene);
        scene.* = try Scene.init(self.allocator, sceneName);
        try self.registry.addScene(scene);

        return .{ .ptr = scene };
    }
};
