// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
const std = @import("std");
const zlua = @import("zlua");
const log = @import("../../log.zig").lua;
const Lua = zlua.Lua;
const marshal = @import("marshal.zig");

/// Registers a class, exposing it to Lua under the given name. Instances are
/// created via creating userdata elsewhere (like `marshal.push`), this just
/// makes the metatable so that `:` method calls work. To hide fields or
/// functions, add a list in the type:
/// ```zig
/// pub const hidden = .{ "funcA", "funcB", "fieldA" };
/// ```
/// To override the name the type is given in Lua, add it in the type:
/// ```zig
/// pub const name = "EpicType"
/// ```
pub fn registerClass(l: *Lua, comptime T: type, comptime name: [:0]const u8) !void {
    const real_name = comptime optionalOverrideName(T, name);

    l.newMetatable(real_name) catch |e| {
        log.err("Error when creating metatable for '{s}': {s}.", .{ real_name, @errorName(e) });
    };
    l.pushFunction(zlua.wrap(marshal.wrapIndex(T, real_name)));
    l.setField(-2, "__index");
    l.pushFunction(zlua.wrap(marshal.wrapNewIndex(T, real_name)));
    l.setField(-2, "__newindex");
    if (@hasDecl(T, "operators")) {
        marshal.wrapOps(l, T);
    }

    if (std.meta.hasFn(T, "format")) {
        l.pushFunction(zlua.wrap(marshal.wrapToString(T)));
        l.setField(-2, "__tostring");
    }

    if (std.meta.hasFn(T, "deinit") and !@hasDecl(T, "lua_ref")) {
        l.pushFunction(zlua.wrap(marshal.wrapGc(T, real_name)));
        l.setField(-2, "__gc");
    }

    l.pop(1);
}

fn optionalOverrideName(comptime T: type, comptime default_name: [:0]const u8) [:0]const u8 {
    if (@hasDecl(T, "name")) return @field(T, "name");
    if (@hasDecl(T, "lua_name")) return @field(T, "lua_name");

    return default_name;
}
