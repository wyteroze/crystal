// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const marshal = @import("marshal.zig");

/// If an `init` function exists in the module, this calls it with the args it wants.
/// Note that params are matched by type and not name, so for example `blablabla: std.mem.Allocator` would be matched as long as you provide the same std.mem.Allocator type in the ctx.
pub fn callInitWithMatchingArgs(comptime Lib: type, ctx: anytype) !Lib {
    if (!std.meta.hasFn(Lib, "init")) @compileError(@typeName(Lib) ++ " does not have an init function, but it needs one");

    const init_fn = @field(Lib, "init");
    const InitFn = @TypeOf(init_fn);
    const Params = @typeInfo(InitFn).@"fn".params;
    const ctx_fields = comptime std.meta.fields(@TypeOf(ctx));

    var args: std.meta.ArgsTuple(InitFn) = undefined;

    inline for (Params, 0..) |p, i| {
        const ParamType = p.type.?;
        const matching = comptime findMatchingType(ctx_fields, ParamType);

        args[i] = @field(ctx, matching);
    }

    const result = @call(.auto, init_fn, args);
    return switch (@typeInfo(@TypeOf(result))) {
        .error_union => try result,
        else => result,
    };
}

/// Registers a module, exposing it to Lua under the same name (unless overridden). To hide fields or functions, add a list in the library:
/// ```zig
/// pub const hidden = .{ "funcA", "funcB", "fieldA" };
/// ```
/// "allocator", "io" are always implicitly hidden.
/// To override the name the module is given in Lua, add it in the library:
/// ```zig
/// pub const name = "EpicLib"
/// ```
pub fn registerModule(l: *Lua, comptime Lib: type, instance: *Lib, comptime name: [:0]const u8) !void {
    const real_name = comptime optionalOverrideName(Lib, name);

    const ud = l.newUserdata(Lib, 0);
    ud.* = instance.*;

    try l.newMetatable(real_name);

    l.pushFunction(zlua.wrap(marshal.wrapModuleIndex(Lib, real_name)));
    l.setField(-2, "__index");
    l.pushFunction(zlua.wrap(marshal.wrapNewIndex(Lib, real_name)));
    l.setField(-2, "__newindex");
    if (std.meta.hasFn(Lib, "deinit")) {
        l.pushFunction(zlua.wrap(marshal.wrapGc(Lib, real_name)));
        l.setField(-2, "__gc");
    }
    l.setMetatable(-2);

    l.setGlobal(real_name);
}

fn findMatchingType(comptime fields: []const std.builtin.Type.StructField, comptime T: type) [:0]const u8 {
    inline for (fields) |f| {
        if (f.type == T) return f.name;
    }

    @compileError("no ctx value of type '" ++ @typeName(T) ++ "' is available for a module init param; add one to the ctx tuple in ScriptEngine.init");
}

fn optionalOverrideName(comptime T: type, comptime default_name: [:0]const u8) [:0]const u8 {
    if (@hasDecl(T, "name")) return @field(T, "name");
    return default_name;
}
