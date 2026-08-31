// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;

pub fn isBoundType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"enum", .@"union", .@"opaque" => @hasDecl(T, "__lua"),
        else => false
    };
}

pub fn Binding(comptime T: type, comptime is_ref: bool) type {
    const Stored = if (is_ref) *T else T;
    return struct {
        pub const type_name = @typeName(T);
        pub const ref = is_ref;

        pub fn push(l: *Lua, v: Stored) void {
            const udata = l.newUserdata(Stored, 0);
            udata.* = v;

            l.setMetatableRegistry(type_name);
        }

        pub fn checkPtr(l: *Lua, idx: i32) *Stored {
            return l.checkUserdata(Stored, idx, type_name);
        }

        pub fn check(l: *Lua, idx: i32) Stored {
            return checkPtr(l, idx).*;
        }
    };
}

pub fn pushVal(l: *Lua, comptime T: type, val: T) void {
    const is_ptr = @typeInfo(T) == .pointer;
    const Inner = if (is_ptr) @typeInfo(T).pointer.child else T;

    if (comptime isBoundType(Inner)) {
        Binding(Inner, Inner.__lua == .ref).push(l, val);
    } else {
        l.pushAny(val) catch unreachable;
    }
}

pub fn parseVal(l: *Lua, comptime ParamType: type, idx: i32) !ParamType {
    const is_ptr = @typeInfo(ParamType) == .pointer;
    const Inner = if (is_ptr) @typeInfo(ParamType).pointer.child else ParamType;

    if (comptime isBoundType(Inner)) {
        return Binding(Inner, Inner.__lua == .ref).check(l, idx);
    } else {
        return l.toAny(ParamType, idx);
    }
}
