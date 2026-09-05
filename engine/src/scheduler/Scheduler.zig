// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
pub const Counter = @import("Counter.zig");
pub const Job = @import("Job.zig");
const Fiber = @import("Fiber.zig");
const Deque = @import("Deque.zig").Deque;
const Os = @import("../os/Os.zig");
const MPMCQueue = @import("MPMCQueue.zig").MPMCQueue;

const fiber_pool_size = 512;
const fiber_stack_size = 64 * 1024; // 64KB
const stack_mem_size = 256 * 1024;
const Runnable = union(enum) { job: Job, fiber: *Fiber };
const PendingPark = struct { fiber: *Fiber, counter: *Counter };

const Scheduler = @This();
os: *const Os,
io: std.Io,
allocator: std.mem.Allocator,
fibers: []Fiber,
free_fibers: MPMCQueue(*Fiber, fiber_pool_size),
ready_fibers: []Deque(*Fiber),
home_fibers: []Fiber,
workers: []std.Thread,
// One for each job priority (critical, high, normal, low, background)
deques: [std.meta.fields(Job.JobPriority).len][]Deque(Job),
running: std.atomic.Value(bool) = .init(true),

var next_submit_worker: std.atomic.Value(usize) = .init(0);
threadlocal var worker_id: usize = 0;
threadlocal var tls_self: *Scheduler = undefined;
threadlocal var pending_park: ?PendingPark = null;
threadlocal var current_fiber: *Fiber = undefined;

pub fn init(self: *Scheduler, allocator: std.mem.Allocator, io: std.Io, os: *const Os) !void {
    const topology = try os.scheduling().getTopology(allocator);
    defer topology.deinit(allocator);

    const core_count = topology.cores.len;

    var fibers: std.ArrayList(Fiber) = try .initCapacity(allocator, fiber_pool_size); 
    errdefer { for (fibers.items) |*f| f.deinit(allocator); fibers.deinit(allocator); }
    for (0..fiber_pool_size) |_| {
        fibers.appendAssumeCapacity(try .init(allocator, fiber_stack_size));
    }
    const owned_fibers = try fibers.toOwnedSlice(allocator);
    errdefer allocator.free(owned_fibers);

    var free_fibers: MPMCQueue(*Fiber, fiber_pool_size) = .init(io);
    for (owned_fibers) |*f| try free_fibers.push(f);

    // These represent the thread's existing stack, and only ever hold saved register state.
    // One for each OS thread
    var home_fibers: std.ArrayList(Fiber) = try .initCapacity(allocator, core_count);
    errdefer home_fibers.deinit(allocator);
    home_fibers.appendNTimesAssumeCapacity(.{ .stack = &.{} }, core_count);
    
    // For fibers that have been woken, but not resumed. These are processed before jobs.
    var ready_fibers: std.ArrayList(Deque(*Fiber)) = try .initCapacity(allocator, core_count);
    errdefer { for (ready_fibers.items) |*dq| dq.deinit(allocator);  }
    for (0..core_count) |_| ready_fibers.appendAssumeCapacity(try .init(allocator, 4096));

    var deques: [std.meta.fields(Job.JobPriority).len][]Deque(Job) = undefined;
    errdefer { for (deques) |dq| { for (dq) |*d| d.deinit(allocator); allocator.free(dq); } }

    for (&deques) |*dq| {
        var list: std.ArrayList(Deque(Job)) = try .initCapacity(allocator, core_count);
        for (0..core_count) |_| try list.append(allocator, try .init(allocator, 4096));
        dq.* = try list.toOwnedSlice(allocator);
    }

    tls_self = self;
    self.* = .{
        .os = os,
        .io = io,
        .allocator = allocator,
        .fibers = owned_fibers,
        .free_fibers = free_fibers,
        .ready_fibers = try ready_fibers.toOwnedSlice(allocator),
        .home_fibers = try home_fibers.toOwnedSlice(allocator),
        .workers = try allocator.alloc(std.Thread, core_count), // set below
        .deques = deques
    };

    for (0..core_count) |i| {
        const core = topology.cores[i];
        self.workers[i] = try std.Thread.spawn(.{}, workerMain, .{ self, core });
    }

}

pub fn deinit(self: *Scheduler) void {
    self.running.store(false, .release);
    for (self.workers) |w| w.join();

    for (self.fibers) |*f| f.deinit(self.allocator);
    self.allocator.free(self.fibers);

    for (self.deques) |dq| {
        for (dq) |*d| d.deinit(self.allocator);
        self.allocator.free(dq);
    }
    for (self.ready_fibers) |*d| d.deinit(self.allocator);
    self.allocator.free(self.ready_fibers);

    self.allocator.free(self.home_fibers);
    self.allocator.free(self.workers);
}

/// Returns the thread's pointer to Scheduler
pub fn current() *Scheduler {
    return tls_self;
}

pub fn currentHomeFiber() *Fiber {
    return &tls_self.home_fibers[worker_id];
}

fn workerMain(self: *Scheduler, parent_core: Os.Scheduling.Core) void {
    tls_self = self;
    worker_id = parent_core.id;

    const home = &self.home_fibers[worker_id];
    while (self.running.load(.acquire)) {
        const runnable = self.popNextRunnable() orelse {
            std.Thread.yield() catch {};
            continue;
        };

        const fiber = self.resolveRunnable(runnable);
        //std.log.debug("workerMain: got fiber {*}", .{ fiber });
        current_fiber = fiber;
        home.switchTo(fiber);

        if (current_fiber.state == .finished) {
            //std.log.debug("workerMain: Freeing fiber {*}", .{ current_fiber });
            self.free_fibers.push(current_fiber) catch |e| @panic(@errorName(e));
        }
    }
}

fn resolveRunnable(self: *Scheduler, runnable: Runnable) *Fiber {
    return switch (runnable) {
        .fiber => |f| { return f; },
        .job => |j| blk: {
            const f = self.free_fibers.pop() 
                orelse std.debug.panic("Fiber pool exhausted. Increase the `fiber_pool_size` or reduce wait-chain depth", .{});
            //std.log.debug("resolveRunnable: Retrieved free fiber {*}", .{ f });

            self.attachJob(f, j);
            break :blk f;
        }
    };
}

fn attachJob(self: *Scheduler, fiber: *Fiber, job: Job) void {
    _ = self;
    fiber.job = job;
    fiber.reset(jobTrampoline, @ptrCast(fiber));
}

pub fn submit(self: *Scheduler, job: Job) void {
    const target = if (tls_self == self) worker_id
        else next_submit_worker.fetchAdd(1, .monotonic) % self.workers.len;
    self.deques[@intFromEnum(job.priority)][target].pushToBottom(job);
}

fn popNextRunnable(self: *Scheduler) ?Runnable {
    // highest priority: ready fibers
    if (self.ready_fibers[worker_id].popFromBottom()) |fiber| return .{ .fiber = fiber };
    
    // then, check our own deques
    for (self.deques) |dq| {
        if (dq[worker_id].popFromBottom()) |job| return .{ .job = job };
    }

    // try stealing fibers from other workers
    const worker_count = self.workers.len;
    var offset: usize = 1;
    while (offset < worker_count) : (offset += 1) {
        const victim = (worker_id + offset) % worker_count;
        if (self.ready_fibers[victim].steal()) |fiber| return .{ .fiber = fiber };
    }

    // finally, try stealing jobs from other workers
    for (self.deques) |dq| {
        offset = 1;
        while (offset < worker_count) : (offset += 1) {
            const victim = (worker_id + offset) % worker_count;
            if (dq[victim].steal()) |job| return .{ .job = job };
        }
    }

    // no jobs to run
    return null;
}

pub fn publishPendingPark(self: *Scheduler) void {
    const p = pending_park orelse return;
    pending_park = null;

    p.counter.lock.lockUncancelable(self.io);
    if (p.counter.value.load(.acquire) == 0) {
        p.counter.lock.unlock(self.io);
        self.makeRunnable(p.fiber);
        return;
    }
    
    p.counter.waiters.append(self.allocator, p.fiber) catch std.debug.panic("Out of memory", .{});
    p.counter.lock.unlock(self.io);
}

pub fn makeRunnable(self: *Scheduler, fiber: *Fiber) void {
    //std.log.debug("makeRunnable: {*}, {d}", .{ fiber, worker_id });
    fiber.state = .idle;
    self.ready_fibers[worker_id].pushToBottom(fiber);
}

pub fn wait(self: *Scheduler, counter: *Counter) void {
    if (counter.value.load(.acquire) == 0) return;

    const next = while (true) {
        if (self.popNextRunnable()) |r| break self.resolveRunnable(r);
        std.Thread.yield() catch {};
    };

    current_fiber.state = .parked;
    const parked_fiber = current_fiber;
    current_fiber = next;

    pending_park = .{ .fiber = parked_fiber, .counter = counter };

    parked_fiber.switchTo(next);
    current_fiber = parked_fiber;
}

pub fn waitBlocking(self: *Scheduler, counter: *Counter) void {
    while (true) {
        if (counter.value.load(.acquire) == 0) {
            counter.lock.lockUncancelable(self.io);
            defer counter.lock.unlock(self.io);

            if (counter.value.load(.acquire) == 0) return;
        }

        std.Thread.yield() catch {};
    }
}

fn jobTrampoline(data: *anyopaque) void {
    //std.log.debug("jobTrampoline: {*}", .{ tls_self });
    const fiber: *Fiber = @ptrCast(@alignCast(data));
    const job = fiber.job.?;
    job.func(job.data);

    if (job.counter) |c| c.decrement(tls_self.io, tls_self);
}