// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Os = @import("../../Os.zig");
const c = @import("c");

const Scheduling = @This();
proc_init: std.process.Init,

pub fn init(proc_init: std.process.Init) Scheduling {
    return .{ .proc_init = proc_init };
}

pub fn getTopology(self: Scheduling, allocator: std.mem.Allocator) !Os.Scheduling.CoreTopology {
    _ = self;

    // Query the number of performance cores
    const perf_count = sysctlU32("hw.perflevel0.logicalcpu") orelse blk: {
        std.log.warn("failed to query hw.perflevel0.logicalcpu, defaulting to 0", .{});
        break :blk 0;
    };
    // Query the number of efficiency cores
    const eff_count = sysctlU32("hw.perflevel1.logicalcpu") orelse blk: {
        std.log.warn("failed to query hw.perflevel1.logicalcpu, defaulting to 0", .{});
        break :blk 0;
    };

    const total = if (perf_count + eff_count > 0) perf_count + eff_count
        else std.Thread.getCpuCount() catch blk: {
            std.log.warn("failed to query std.Thread.getCpuCount(), defaulting to 1 (single-core)", .{});
            break :blk 1;
        };
    
    const cores = try allocator.alloc(Os.Scheduling.Core, total);
    const perf_indices = try allocator.alloc(usize, perf_count);
    const eff_indices = try allocator.alloc(usize, eff_count);

    // Fake the indices since darwin doesn't let us get core id
    var i: usize = 0;
    while (i < perf_count) : (i += 1) {
        cores[i] = .{ .id = i, .size = .big };
        perf_indices[i] = i;
    }
    var j: usize = 0;
    while (j < eff_count) : (j += 1) {
        cores[perf_count + j] = .{ .id = perf_count + j, .size = .small };
        eff_indices[j] = perf_count + j;
    }

    if (perf_count + eff_count == 0) {
        // perflevel gave no data, just mark every core as normal
        for (cores, 0..) |*core, idx| core.* = .{ .id = idx, .size = .normal };
    }

    return .{
        .cores = cores,
        .performance_cores = perf_indices,
        .efficiency_cores = eff_indices,
    };
}

pub fn setThreadPriority(self: Scheduling, priority: Os.Scheduling.ThreadPriority) void {
    _ = self;

    const qos: c.qos_class_t = switch (priority) {
        .critical => c.QOS_CLASS_USER_INTERACTIVE,
        .high => c.QOS_CLASS_USER_INITIATED,
        .normal => c.QOS_CLASS_DEFAULT,
        .low => c.QOS_CLASS_UTILITY,
        .lowest => c.QOS_CLASS_BACKGROUND
    };

    _ = c.pthread_set_qos_class_self_np(qos, 0);
}

fn sysctlU32(name: [:0]const u8) ?u32 {
    var value: u32 = 0;
    var size: usize = @sizeOf(u32);

    const rc = c.sysctlbyname(name.ptr, &value, &size, null, 0);
    if (rc != 0) return null;

    return value;
}