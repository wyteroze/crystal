// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const World = @import("World.zig");

pub const SystemFn = *const fn (world: *World, dt: f32, ctx: *anyopaque) void;
pub const SystemEntry = struct {
    pub const __lua = .ref;

    registry: *SystemRegistry,
    name: []const u8,
    run: SystemFn,
    ctx: *anyopaque,
    dtor: ?*const fn (allocator: std.mem.Allocator, ctx: *anyopaque) void = null,

    pub fn unregister(self: *SystemEntry) void {
        self.registry.unregister(self.name);
    }
};

const SystemRegistry = @This();
allocator: std.mem.Allocator,
systems: std.ArrayList(SystemEntry),

pub fn init(allocator: std.mem.Allocator) SystemRegistry {
    return .{ .allocator = allocator, .systems = .empty };
}

pub fn deinit(self: *SystemRegistry) void {
    for (self.systems.items) |s| if (s.dtor) |d| d(self.allocator, s.ctx);
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
        .registry = self,
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

pub fn registerErased(self: *SystemRegistry, name: []const u8, run: SystemFn, ctx: *anyopaque, dtor: ?*const fn (allocator: std.mem.Allocator, ctx: *anyopaque) void) !void {
    try self.systems.append(self.allocator, .{ .registry = self, .name = name, .run = run, .ctx = ctx, .dtor = dtor });
}

pub fn unregister(self: *SystemRegistry, name: []const u8) void {
    var i: usize = 0;

    while (i < self.systems.items.len) {
        const system = self.systems.items[i];
        if (std.mem.eql(u8, system.name, name)) {
            if (system.dtor) |d| d(self.allocator, system.ctx);
            _ = self.systems.swapRemove(i);
            return;
        }

        i += 1;
    }
}

pub fn runAll(self: *SystemRegistry, world: *World, dt: f32) void {
    for (self.systems.items) |s| s.run(world, dt, s.ctx);
}

pub fn registerLua(l: anytype) void {
    const linker = @import("../scripting/linker/linker.zig");

    linker.reference(l, SystemEntry, .{
        .name = .{ .named = "System" },
        .methods = &.{
            .named("Unregister", SystemEntry.unregister)
        }
    });
}
