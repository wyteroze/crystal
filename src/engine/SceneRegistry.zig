// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Scene = @import("../Scene.zig").Scene;

pub const SceneRegistry = struct {
    allocator: std.mem.Allocator,
    scenes: std.ArrayList(*Scene),

    pub fn init(allocator: std.mem.Allocator) SceneRegistry {
        return .{
            .allocator = allocator,
            .scenes = std.ArrayList(*Scene).empty,
        };
    }

    pub fn deinit(self: *SceneRegistry) void {
        for (self.scenes.items) |s| {
            s.deinit();
            self.allocator.destroy(s);
        }

        self.scenes.deinit(self.allocator);
    }

    pub fn addScene(self: *SceneRegistry, scene: *Scene) !void {
        try self.scenes.append(self.allocator, scene);
    }

    pub fn removeScene(self: *SceneRegistry, scene: *Scene) void {
        for (self.scenes.items, 0..) |s, i| {
            if (s == scene) {
                s.deinit();
                _ = self.scenes.swapRemove(i);
                self.allocator.destroy(s);

                return;
            }
        }
    }
};
