// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Fiber = @import("Fiber.zig");
const Scheduler = @import("Scheduler.zig");

const Counter = @This();
value: std.atomic.Value(u32) = .init(0),
waiters: std.ArrayList(*Fiber) = .empty,
lock: std.Io.Mutex = .init,

pub fn add(self: *Counter, n: u32) void {
    _ = self.value.fetchAdd(n, .monotonic);
}

pub fn decrement(self: *Counter, io: std.Io, scheduler: *Scheduler) void {
    if (self.value.fetchSub(1, .release) == 1) {
        self.lock.lockUncancelable(io);
        
        var waiters = self.waiters;
        self.waiters = .empty;
        self.lock.unlock(io);

        for (waiters.items) |fiber| scheduler.makeRunnable(fiber);
        waiters.clearAndFree(scheduler.allocator);
    }
}