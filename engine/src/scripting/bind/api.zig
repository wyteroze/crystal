// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const bind = @import("bind.zig");
const types = @import("types.zig");
const discover = @import("discover.zig");
const engine = @import("../../engine.zig");

pub const all: []const types.Member = blk: {
    const found = discover.discover(engine);

    var loose: []const types.Member = &.{};
    var containers: []const types.Member = &.{};

    for (found) |m| switch (m.kind) {
        .value, .func, .constant => loose = loose ++ .{ m },
        .globals, .module => containers = containers ++ .{ m },
        else => @compileError("unexpected top-level api member: " ++ m.name),
    };
    
    break :blk &[_]types.Member{bind.globals(.{ .members = loose })} ++ containers;
};