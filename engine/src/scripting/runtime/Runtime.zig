// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const bind = @import("../bind/bind.zig");
const ecs = @import("../../ecs/ecs.zig");
const Assets = @import("../../assets/Assets.zig");
const Input = @import("../../input/Input.zig");
const Ui = @import("../../ui/Ui.zig");
const Audio = @import("../../audio/Audio.zig");
const Script = @import("Script.zig");

const Runtime = @This();
state: *zlua.Lua,
binder: bind.Binder(bind.api),

pub fn init(allocator: std.mem.Allocator, host: *bind.Host) !Runtime {
    const l: *zlua.Lua = try .init(allocator);
    l.openLibs();

    var binder: bind.Binder(bind.api) = .init(l, host);
    binder.install();

    return .{ .state = l, .binder = binder };
}

pub fn deinit(self: Runtime) void {
    self.state.deinit();
}

pub fn loadScript(self: Runtime, source: Assets.types.ScriptSource) !Script {
    return .init(self.state.newThread(), source, self.binder);
}

pub fn gcCount(self: Runtime) i32 {
    return self.state.gcCount();
}
