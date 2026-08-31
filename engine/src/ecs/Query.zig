// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Entity = @import("Entity.zig");
const ComponentId = @import("ComponentId.zig");
const SparseSet = @import("SparseSet.zig");
const World = @import("World.zig");

const Query = @This();
world: *World,
required: []const ComponentId,

pub fn init(world: *World, required: []const ComponentId) Query {
    return .{ .world = world, .required = required };
}

pub fn iterator(self: Query) Iterator {
    var smallest_idx: usize = 0;
    var smallest_count: usize = std.math.maxInt(usize);

    for (self.required, 0..) |id, i| {
        const set = self.world.storageFor(id) orelse return .{
            .world = self.world,
            .required = self.required,
            .driver = null,
            .cursor = 0
        };

        if (set.count() < smallest_count) {
            smallest_count = set.count();
            smallest_idx = i;
        }
    }

    const driver = self.world.storageFor(self.required[smallest_idx]) orelse return .{
        .world = self.world,
        .required = self.required,
        .driver = null,
        .cursor = 0
    };

    return .{
        .world = self.world,
        .required = self.required,
        .driver = driver,
        .cursor = 0
    };
}

pub const Iterator = struct {
    world: *World,
    required: []const ComponentId,
    driver: ?*SparseSet,
    cursor: usize,

    pub fn next(self: *Iterator) ?Entity {
        const driver = self.driver orelse return null;
        const driver_entities = driver.entities();

        while (self.cursor < driver_entities.len) {
            const entity = driver_entities[self.cursor];
            self.cursor += 1;

            var matches = true;
            for (self.required) |id| {
                const set = self.world.storageFor(id) orelse {
                    matches = false;
                    break;
                };

                if (!set.has(entity)) {
                    matches = false;
                    break;
                }
            }

            if (matches) return entity;
        }

        return null;
    }
};
