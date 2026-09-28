// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const util = @import("util.zig");

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

pub fn Parsed(comptime T: type) type {
    return struct {
        arena: ?*std.heap.ArenaAllocator,
        value: T,

        pub fn deinit(self: @This()) void {
            const arena = self.arena orelse return;
            arena.deinit();
            arena.child_allocator.destroy(arena);
        }
    };
}

pub fn pushVal(l: *Lua, comptime T: type, val: T) void {
    const is_ptr = @typeInfo(T) == .pointer;
    const Inner = if (is_ptr) @typeInfo(T).pointer.child else T;

    if (comptime isBoundType(Inner)) {
        Binding(Inner, Inner.__lua == .ref).push(l, val);
    } else {
        switch (@typeInfo(Inner)) {
            .@"enum" => _ = l.pushString(util.pascalCaseTag(Inner, val)),
            else => l.pushAny(val) catch unreachable
        }
    }
}

pub fn parseVal(l: *Lua, comptime ParamType: type, idx: i32) !ParamType {
    const is_ptr = @typeInfo(ParamType) == .pointer;
    const Inner = if (is_ptr) @typeInfo(ParamType).pointer.child else ParamType;

    if (comptime isBoundType(Inner)) {
        return Binding(Inner, Inner.__lua == .ref).check(l, idx);
    } else {
        return switch (@typeInfo(Inner)) {
            .@"enum" => blk: {
                const str = l.toString(idx) catch |e| util.luaErr(l, e, .{ []const u8, idx });
                break :blk util.snakeCaseFromPascal(Inner, str) orelse util.luaErr(l, error.InvalidEnumTag, .{});
            },
            else => return l.toAny(ParamType, idx)
        };
    }
}

pub fn parseValAlloc(l: *Lua, comptime ParamType: type, idx: i32) !Parsed(ParamType) {
    const is_ptr = @typeInfo(ParamType) == .pointer;
    const Inner = if (is_ptr) @typeInfo(ParamType).pointer.child else ParamType;

    if (comptime isBoundType(Inner)) {
        return .{
            .arena = null,
            .value = Binding(Inner, Inner.__lua == .ref).check(l, idx)
        };
    } else {
        const result: zlua.Parsed(ParamType) = switch (@typeInfo(ParamType)) {
            .@"enum" => .{
                .arena = null,
                .value = util.snakeCaseFromPascal(Inner, try l.toString(idx)) 
                    orelse return error.InvalidEnumTag
            },
            else => try l.toAnyAlloc(ParamType, idx)
        };
        return .{
            .arena = result.arena,
            .value = result.value
        };
    }
}