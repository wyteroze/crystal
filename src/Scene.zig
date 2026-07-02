// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Instance = @import("Instance.zig").Instance;

pub const Scene = struct {
    allocator: std.mem.Allocator,
    instances: std.ArrayList(Instance),

    pub fn init(allocator: std.mem.Allocator) !Scene {
        return .{
            .allocator = allocator,
            .instances = std.ArrayList(Instance).empty
        };
    }

    pub fn deinit(self: Scene) !Scene {
        self.instances.deinit(self.allocator);
    }
};
