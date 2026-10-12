// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

pub const ComponentId = @import("ComponentId.zig");
pub const ComponentRegistry = @import("ComponentRegistry.zig");
pub const SystemRegistry = @import("SystemRegistry.zig");
pub const Entity = @import("Entity.zig");
pub const Query = @import("Query.zig");
pub const SparseSet = @import("SparseSet.zig");
pub const World = @import("World.zig");

const scripting = @import("../scripting/scripting.zig");
const bind = scripting.bind;
const lua_signal = scripting.lua_signal;

pub const api = bind.module("ecs", .{
    .kind = .library,
    .members = &.{
        Entity.sub_api,
        lua_signal.connection,
        lua_signal.handle(World.UpdateSignal),
        lua_signal.handle(World.DestroySignal),
    }
});