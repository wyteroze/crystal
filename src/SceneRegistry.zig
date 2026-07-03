// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Scene = @import("Scene.zig").Scene;

pub const ScenePtr = struct {
    scene: *Scene,
    cleanup_ctx: ?*anyopaque = null,
    cleanup_fn: ?*const fn (ctx: ?*anyopaque) void = null
};

pub const SceneRegistry = struct {
    allocator: std.mem.Allocator,
    scenes: std.ArrayList(ScenePtr),

    pub fn init(allocator: std.mem.Allocator) SceneRegistry {
        return .{
            .allocator = allocator,
            .scenes = std.ArrayList(ScenePtr).empty
        };
    }

    pub fn deinit(self: *SceneRegistry) void {
        for (self.scenes.items) |s| {
            if (s.cleanup_fn) |f| f(s.cleanup_ctx);
        }

        self.scenes.deinit(self.allocator);
    }

    pub fn addScene(self: *SceneRegistry, scene: ScenePtr) !void {
        try self.scenes.append(self.allocator, scene);
    }

    pub fn removeScene(self: *SceneRegistry, scene: *ScenePtr) void {
        for (self.scenes.items, 0..) |*s, i| {
            if (s == scene) {
                _ = self.scenes.swapRemove(i);
                return;
            }
        }
    }
};
