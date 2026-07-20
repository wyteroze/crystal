// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const Engine = @import("engine/Engine.zig").Engine;
const perf = @import("profile/perf.zig");

// You can customize this to filter what types of logs
// are actually seen in the output
pub const std_options: std.Options = .{
    // Default log level
    .log_level = .info,

    // Filters for scopes
    .log_scope_levels = &.{
        .{ .scope = .script, .level = .info },
        .{ .scope = .render, .level = .info },
        .{ .scope = .parse, .level = .info },
        .{ .scope = .engine, .level = .info }
    }
};

pub fn main(init: std.process.Init) !void {
    var engine: Engine = undefined;
    try engine.init(init.gpa, init.io);
    defer engine.deinit();

    perf.registry = &engine.thread_registry;
    perf.frequency = sdl3.timer.getPerformanceFrequency();
    perf.enabled = true;

    while (engine.running) try engine.step();
}
