// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const ThreadRegistry = @import("../engine/ThreadRegistry.zig").ThreadRegistry;
const log = @import("../log.zig").threading;

const MAX_ZONES = 4096;
const MAX_DEPTH = 64;

pub const Zone = struct {
    name: []const u8,
    start: u64,
    elapsed: u64,
    depth: u16,
    parent: i32 // -1 if top-level
};

const ThreadContext = struct {
    zones: [2][MAX_ZONES]Zone = undefined,
    counts: [2]usize = .{ 0, 0 },
    write_buf: u1 = 0,
    ready_buf: u1 = 0,

    stack: [MAX_DEPTH]usize = undefined,
    stack_top: usize = 0,

    frame_start_ticks: u64 = 0,
    frame_ticks: u64 = 0,

    name: []const u8 = "thread",
    registered: bool = false,
    id: usize = 0,
};

threadlocal var tls = ThreadContext{};
pub var enabled: bool = false;
pub var frequency: u64 = undefined;
pub var registry: *ThreadRegistry = undefined;
var contexts: [ThreadRegistry.MAX_THREADS]*ThreadContext = undefined;

pub fn start(name: []const u8) void {
    if (!enabled) return;
    const t = &tls;

    if (t.stack_top >= MAX_DEPTH) return;

    const idx = t.counts[t.write_buf];
    if (idx >= MAX_ZONES) return;

    const parent = @as(i32, if (t.stack_top == 0) -1
        else @intCast(t.stack[t.stack_top - 1]));

    t.zones[t.write_buf][idx] = .{
        .name = name,
        .start = sdl3.timer.getPerformanceCounter(),
        .elapsed = 0,
        .depth = @intCast(t.stack_top),
        .parent = parent
    };

    t.stack[t.stack_top] = idx;
    t.stack_top += 1;

    t.counts[t.write_buf] = idx + 1;
}

pub fn stop() void {
    if (!enabled) return;
    const t = &tls;

    if (t.stack_top == 0) return;
    t.stack_top -= 1;

    const idx = t.stack[t.stack_top];
    const now = sdl3.timer.getPerformanceCounter();

    t.zones[t.write_buf][idx].elapsed = now - t.zones[t.write_buf][idx].start;
}

pub fn beginFrame(name: ?[]const u8) !void {
    if (!enabled) return;
    const t = &tls;
    if (name) |n| {
        t.name = n;
    }

    if (!t.registered) try register(t);

    t.stack_top = 0;
    t.counts[t.write_buf] = 0;
    t.frame_start_ticks = sdl3.timer.getPerformanceCounter();
}

pub fn endFrame() void {
    if (!enabled) return;
    const t = &tls;

    t.frame_ticks = sdl3.timer.getPerformanceCounter() - t.frame_start_ticks;

    @atomicStore(u1, &t.ready_buf, t.write_buf, .release);
    t.write_buf ^= 1;
}

fn register(t: *ThreadContext) !void {
    const id = try registry.register(t.name);
    t.id = id;
    contexts[id] = t;

    t.registered = true;
}

pub fn msFromTicks(ticks: u64) f64 {
    return @floatCast(@as(f64, @floatFromInt(ticks)) * 1000.0 / @as(f64, @floatFromInt(frequency)));
}

pub fn threadCount() usize { return registry.threadCount(); }
pub fn threadName(id: usize) []const u8 { return registry.name(id); }
pub fn threadFrameMs(id: usize) f64 { return msFromTicks(contexts[id].frame_ticks); }

pub fn threadZones(id: usize) []const Zone {
    const t = contexts[id];
    const rb = @atomicLoad(u1, &t.ready_buf, .acquire);

    return t.zones[rb][0..t.counts[rb]];
}

pub fn dumpToLog() void {
    if (!enabled) return;

    const id = 0;
    const zones = threadZones(id);

    log.info("-----[perf dump]-----", .{});

    for (zones) |z| {
        log.info("zone '{s}' ({d}): ", .{ z.name, id });
        log.info("    elapsed ms: {d}", .{ msFromTicks(z.elapsed) });
    }

    log.info("---------------------", .{});
}
