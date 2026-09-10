// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const linker = @import("../linker/linker.zig");
const ecs = @import("../../ecs/ecs.zig");
const Assets = @import("../../assets/Assets.zig");
const c = zlua.c;
const Lua = zlua.Lua;
const Script = @import("Script.zig");

const Runtime = @This();
state: *Lua,
world: *ecs.World,
assets: *Assets,

/// `linkState` must be called immediately after this.
pub fn init(allocator: std.mem.Allocator, world: *ecs.World, assets: *Assets) !Runtime {
    const l: *Lua = try .init(allocator);
    l.openLibs();

    linker.registry.registerAll(l);
    return .{ .state = l, .world = world, .assets = assets };
}

pub fn deinit(self: Runtime) void {
    self.state.deinit();
}

pub fn linkState(self: *Runtime) void {
    const raw_space = self.state.getExtraSpace();
    const space_ptr: **Runtime = @ptrCast(@alignCast(raw_space));

    space_ptr.* = self;
}

/// Gets and returns the pointer of the Runtime that created the state,
/// which is stored in the state's extra space (linkState() must have been called first)
pub fn fromState(state: *Lua) *Runtime {
    const raw_space = state.getExtraSpace();
    const space_ptr: **Runtime = @ptrCast(@alignCast(raw_space));

    return space_ptr.*;
}

pub fn loadScript(self: Runtime, source: Assets.types.ScriptSource) !Script {
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