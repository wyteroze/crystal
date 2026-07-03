// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Object = @import("Object.zig").Object;

pub const UpdateCallback = struct {
    ctx: ?*anyopaque,
    func: *const fn (ctx: ?*anyopaque, dt: f32) void,
};

pub const Scene = struct {
    allocator: std.mem.Allocator,
    objects: std.ArrayList(Object),
    name: ?[]const u8,
    callbacks: std.ArrayList(UpdateCallback),

    pub fn init(allocator: std.mem.Allocator, name: ?[]const u8) Scene {
        return .{
            .name = name,
            .allocator = allocator,
            .objects = std.ArrayList(Object).empty,
            .callbacks = std.ArrayList(UpdateCallback).empty
        };
    }

    pub fn deinit(self: *Scene) void {
        self.objects.deinit(self.allocator);
        self.callbacks.deinit(self.allocator);
    }

    pub fn addObject(self: *Scene, object: Object) !void {
        try self.objects.append(self.allocator, object);
    }

    pub fn removeObject(self: *Scene, object: *const Object) void {
        for (self.objects.items, 0..) |*obj, i| {
            if (obj == object) {
                _ = self.objects.swapRemove(i);
                return;
            }
        }
    }

    pub fn addUpdateCallback(self: *Scene, cb: UpdateCallback) !void {
        try self.callbacks.append(self.allocator, cb);
    }

    pub fn removeUpdateCallback(self: *Scene, ctx: ?*anyopaque) void {
        for (self.callbacks.items, 0..) |cb, i| {
            if (cb.ctx == ctx) {
                _ = self.callbacks.swapRemove(i);
                return;
            }
        }
    }

    pub fn update(self: *Scene, dt: f32) void {
        for (self.callbacks.items) |cb| {
            cb.func(cb.ctx, dt);
        }
    }
};
