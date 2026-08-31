// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const linker = @import("../linker/linker.zig");
const ecs = @import("../../ecs/ecs.zig");
const c = zlua.c;
const Lua = zlua.Lua;
const Script = @import("Script.zig");
const types = @import("../../assets/types.zig");

const Runtime = @This();
state: *Lua,

pub fn init(allocator: std.mem.Allocator) !Runtime {
    const l: *Lua = try .init(allocator);
    l.openLibs();

    linker.registry.registerAll(l);
    return .{ .state = l };
}

pub fn deinit(self: Runtime) void {
    self.state.deinit();
}

pub fn loadScript(self: Runtime, source: types.ScriptSource) !Script {
    return .init(self.state, source);
}

pub fn gcCount(self: Runtime) i32 {
    return self.state.gcCount();
}

pub fn setGenerational(self: Runtime) void {
    _ = self.state.gcSetGenerational(0, 0);
}

pub fn setIncremental(self: Runtime) void {
    _ = self.state.gcSetIncremental(0, 0, 0);
}