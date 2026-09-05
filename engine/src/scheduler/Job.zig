// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Counter = @import("Counter.zig");
const Scheduler = @import("Scheduler.zig");

const Job = @This();
func: *const fn (*anyopaque) void,
data: *anyopaque,
/// Decremented on completion
counter: ?*Counter = null,
priority: JobPriority = .normal,

pub fn Wrap(comptime func: anytype) type {
    return struct {
        args: std.meta.ArgsTuple(@TypeOf(func)),

        pub fn submit(self: *@This(), scheduler: *Scheduler, opts: struct {
            priority: Job.JobPriority = .normal,
            counter: ?*Counter = null
        }) void {
            const wrapped = struct {
                fn c(ctx: *anyopaque) void {
                    const a: *@TypeOf(self.args) = @ptrCast(@alignCast(ctx));
                    @call(.auto, func, a.*);
                }
            }.c;

            if (opts.counter) |c| c.add(1);
            scheduler.submit(.{ 
                .func = wrapped, 
                .data = @ptrCast(&self.args),
                .counter = opts.counter,
                .priority = opts.priority
            });
        }
    };
}

pub const JobPriority = enum(u8) {
    critical = 0,
    high = 1,
    normal = 2,
    low = 3,
    background = 4
};