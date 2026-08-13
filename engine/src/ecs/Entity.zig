// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");

const Entity = @This();
index: u32,
generation: u32,

pub const invalid: Entity = .{ .index = std.math.maxInt(u32), .generation = std.math.maxInt(u32) };

pub fn eql(a: Entity, b: Entity) bool {
    return a.index == b.index and a.generation == b.generation;
}

pub fn toU64(self: Entity) u64 {
    return (@as(u64, self.generation) << 32) | @as(u64, self.index);
}

pub fn fromU64(bits: u64) Entity {
    return .{
        .index = @truncate(bits),
        .generation = @truncate(bits >> 32)
    };
}
