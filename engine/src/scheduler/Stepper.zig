// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Scheduler = @import("Scheduler.zig");
const Counter = @import("Counter.zig");
const Job = @import("Job.zig");

pub const Step = struct { index: i96, dt_ns: u64 };
pub const StepFn = *const fn (ctx: *anyopaque, step: Step) void;

const Stepper = @This();
period_ns: i96,
func: StepFn,
ctx: *anyopaque,
priority: Job.JobPriority = .high,
max_catchup: u32 = 4,

index: i96 = 0,
accum_ns: i96 = 0,
last_ns: i96,
current: Step = undefined,
done: Counter,

pub fn advance(self: *Stepper, now_ns: i96) struct { steps: u32, alpha: f32 } {
    self.accum_ms += now_ns - self.last_ns;
    self.last_ns = now_ns;

    var steps: u32 = 0;
    while (self.accum_ns >= self.period_ns and steps < self.max_catchup) : (steps += 1) {
        self.accum_ns -= self.period_ns;
    }
    if (steps == self.max_catchup) self.accum_ns %= self.period_ns;

    const alpha = @as(f32, @floatFromInt(self.accum_ns)) / @as(f32, @floatFromInt(self.period_ns));
    return .{ .steps = steps, .alpha = alpha };
}

/// Submits one step to the scheduler and blocks this thread until the step has completed.
pub fn runOne(self: *Stepper) void {
    self.current = .{ .index = self.index, .dt_ns = self.period_ns };
    self.index += 1;
    self.done.add(1);

    const sched = Scheduler.current();
    sched.submit(.{
        .func = struct {
            fn c(ctx: *anyopaque) void {
                const slf: *Stepper = @ptrCast(@alignCast(ctx));
                slf.func(slf.ctx, slf.current);
            }
        }.c,
        .data = self,
        .counter = &self.done,
        .priority = self.priority,
    });
    
    sched.waitBlocking(&self.done);
}
