// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
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

pub fn handle(comptime T: type, comptime r: recipes.HandleRecipe) types.Member {
    return .{
        .name = r.name orelse names.shortTypeName(T),
        .kind = .handle,
        .impl = struct { pub const Type = T; pub const recipe = r; }
    };
}

pub fn value(comptime T: type, comptime r: recipes.ValueRecipe) types.Member {
    comptime validateValue(T, r);
    return .{
        .name = r.name orelse names.shortTypeName(T),
        .kind = .value,
        .impl = struct { pub const Type = T; pub const recipe = r; },
    };
}

pub fn record(comptime T: type, comptime r: recipes.RecordRecipe) types.Member {
    comptime validateRecord(T);
    return .{
        .name = r.name orelse names.shortTypeName(T),
        .kind = .record,
        .impl = struct { pub const Type = T; pub const recipe = r; }
    };
}

pub fn signal(comptime name: [:0]const u8, comptime get: anytype) types.Member {
    return .{ .name = name, .kind = .signal, .impl = struct {
        pub const Signal = signalType(get);
        pub const getter = get;
    } };
}

fn validateValue(comptime T: type, comptime r: recipes.ValueRecipe) void {
    inline for (r.fields) |f| if (!@hasField(T, f))
        @compileError(@typeName(T) ++ " has no field '" ++ f ++ "' (listed in .fields)");
    if (@alignOf(T) > 8) @compileError(@typeName(T) ++ ": alignment > 8 is not allowed in Lua userdata");
}

fn validateRecord(comptime T: type) void {
    inline for (@typeInfo(T).@"struct".field_attrs) |f|
        if (f.default_value_ptr == null) 
            @compileError(std.fmt.comptimePrint("{s}.{s} needs a default value to be a record field", .{ @typeName(T), f.name }));
}

fn signalType(comptime get: anytype) type {
    comptime var R = @typeInfo(@TypeOf(get)).@"fn".return_type.?;
    if (@typeInfo(R) == .error_union) R = @typeInfo(R).error_union.payload;

    const info = @typeInfo(R);
    if (info != .pointer or info.pointer.size != .one or !@hasDecl(info.pointer.child, "Args"))
        @compileError("bind.signal getter must return `*S` or `!*S`, where `S` is a signal type!");

    return info.pointer.child;
}