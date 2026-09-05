// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const builtin = @import("builtin");

const Job = @import("Job.zig");
const Scheduler = @import("Scheduler.zig");
const arch = @import("arch/arch.zig");

const Registers = switch (builtin.cpu.arch) {
    .aarch64 => arch.aarch64.Registers,
    .x86_64 => arch.x86_64.Registers,
    else => @compileError("unsupported arch " ++ @tagName(builtin.cpu.arch))
};

const swap = switch (builtin.cpu.arch) {
    .aarch64 => arch.aarch64.swap,
    .x86_64 => arch.x86_64.swap,
    else => unreachable
};

const doSwap = switch (builtin.cpu.arch) {
    .aarch64 => arch.aarch64.doSwap,
    .x86_64 => arch.x86_64.doSwap,
    else => unreachable
};

const initRegs = switch (builtin.cpu.arch) {
    .aarch64 => arch.aarch64.initRegs,
    .x86_64 => arch.x86_64.initRegs,
    else => unreachable
};

comptime {
    @export(&swap, .{ .name = "swap" });
}

pub const State = enum { idle, running, parked, finished };
pub const EntryArg = *anyopaque;
pub const EntryFn = *const fn (EntryArg) void;

const Fiber = @This();

regs: Registers = .{},
stack: []align(16) u8,
state: State = .idle,

entry_fn: EntryFn = undefined,
entry_arg: EntryArg = undefined,

job: ?Job = null,

pub fn init(allocator: std.mem.Allocator, stack_size: usize) !Fiber {
    return .{ .stack = try allocator.alignedAlloc(u8, .@"16", stack_size) };
}

pub fn deinit(self: *Fiber, allocator: std.mem.Allocator) void {
    allocator.free(self.stack);
}

pub fn reset(self: *Fiber, entry_fn: EntryFn, entry_arg: EntryArg) void {
    self.entry_fn = entry_fn;
    self.entry_arg = entry_arg;
    self.state = .idle;

    const top = @intFromPtr(self.stack.ptr) + self.stack.len;
    const aligned_top = top & ~@as(usize, 0xF);

    self.regs = initRegs(aligned_top, self);
}

pub fn resetForJob(self: *Fiber, job: Job) void {
    self.job = job;
    self.entry_fn = jobEntryTrampoline;
    self.entry_arg = @ptrCast(self);
    self.state = .idle;

    const top = @intFromPtr(self.stack.ptr) + self.stack.len;
    const aligned_top = top & ~@as(usize, 0xF);

    self.regs = initRegs(aligned_top, self);
}

fn jobEntryTrampoline(arg: EntryArg) void {
    const fiber: *Fiber = @ptrCast(@alignCast(arg));
    const job = fiber.job.?;
    job.func(job.data);
}

pub fn trampolineLand(self: *Fiber) callconv(.c) noreturn {
    Scheduler.current().publishPendingPark();

    self.state = .running;
    self.entry_fn(self.entry_arg);
    self.state = .finished;

    const home = Scheduler.currentHomeFiber();
    doSwap(&self.regs, &home.regs);
    unreachable;
}

pub fn switchTo(self: *Fiber, target: *Fiber) void {
    doSwap(&self.regs, &target.regs);
    Scheduler.current().publishPendingPark();
}