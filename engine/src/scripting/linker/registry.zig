// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Lua = @import("zlua").Lua;

/// Every binding must be registered here to be linked
const bindings = .{
    @import("../../core/math/Vec3.zig"),
    @import("../../core/math/Quat.zig"),
    @import("../../core/math/Mat4.zig"),
    @import("../../ecs/World.zig"),
    @import("../../ecs/Entity.zig"),
    @import("../../assets/Assets.zig")
};

pub fn registerAll(l: *Lua) void {
    inline for (bindings) |mod| {
        if (@hasDecl(mod, "registerLua")) {
            mod.registerLua(l);
        }
    }
}
