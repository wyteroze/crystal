// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const World = @import("World.zig");

pub const SystemFn = *const fn (world: *World, dt: f32, ctx: *anyopaque) void;
pub const SystemEntry = struct {
    name: []const u8,
    run: SystemFn,
    ctx: *anyopaque
};

const SystemRegistry = @This();
allocator: std.mem.Allocator,
systems: std.ArrayList(SystemEntry),

pub fn init(allocator: std.mem.Allocator) SystemRegistry {
    return .{ .allocator = allocator, .systems = .empty };
}

pub fn deinit(self: *SystemRegistry) void {
    self.systems.deinit(self.allocator);
}

pub fn register(
    self: *SystemRegistry,
    name: []const u8,
    comptime Ctx: type,
    comptime run_fn: fn (world: *World, dt: f32, ctx: *Ctx) void,
    ctx_ptr: *Ctx
) !void {
    try self.systems.append(self.allocator, .{
        .name = name,
        .run = struct {
            fn c(world: *World, dt: f32, ctx: *anyopaque) void {
                const typed_ctx: *Ctx = @ptrCast(@alignCast(ctx));
                run_fn(world, dt, typed_ctx);
            }
        }.c,
        .ctx = @ptrCast(ctx_ptr)
    });
}

pub fn unregister(self: *SystemRegistry, name: []const u8) void {
    var i: usize = 0;

    while (i < self.systems.items.len) {
        const system_name = self.systems.items[i].name;
        if (std.mem.eql(u8, system_name, name)) {
            _ = self.systems.swapRemove(i);
            return;
        }

        i += 1;
    }
}

pub fn runAll(self: *SystemRegistry, world: *World, dt: f32) void {
    for (self.systems.items) |s| s.run(world, dt, s.ctx);
}
