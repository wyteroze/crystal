// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const types = @import("types.zig");
const names = @import("names.zig");
const recipes = @import("recipes.zig");

pub fn func(comptime name: [:0]const u8, comptime f: anytype) types.Member {
    return .{ .name = name, .kind = .func, .impl = struct { pub const function = f; } };
}

pub fn constant(comptime name: [:0]const u8, comptime v: anytype) types.Member {
    return .{ .name = name, .kind = .constant, .impl = struct { pub const val = v; } };
}

pub fn prop(comptime name: [:0]const u8, comptime get: anytype, comptime set: anytype) types.Member {
    return .{ .name = name, .kind = .prop, .impl = struct { pub const getter = get; pub const setter = set; } };
}

pub fn readonly(comptime name: [:0]const u8, comptime get: anytype) types.Member {
    return .{ .name = name, .kind = .prop, .impl = struct { pub const getter = get; } };
}

pub fn module(comptime name: [:0]const u8, comptime r: recipes.ModuleRecipe) types.Member {
    return .{ .name = name, .kind = .module, .impl = struct { pub const recipe = r; } };
}

pub fn globals(comptime r: recipes.GlobalsRecipe) types.Member {
    return .{ .name = "", .kind = .globals, .impl = struct { pub const recipe = r; } };
}

pub fn value(comptime T: type, comptime r: recipes.ValueRecipe) types.Member {
    comptime validateValue(T, r);
    return .{
        .name = r.name orelse names.shortTypeName(T),
        .kind = .value,
        .impl = struct { pub const Type = T; pub const recipe = r; },
    };
}

fn validateValue(comptime T: type, comptime r: recipes.ValueRecipe) void {
    inline for (r.fields) |f| if (!@hasField(T, f))
        @compileError(@typeName(T) ++ " has no field '" ++ f ++ "' (listed in .fields)");
    if (@alignOf(T) > 8) @compileError(@typeName(T) ++ ": alignment > 8 is not allowed in Lua userdata");
}
