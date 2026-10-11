// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("types.zig");

const skip = .{ "std", "builtin", "toml", "zlua", "scripting" };

pub fn discover(comptime Root: type) []const types.Member { comptime {
    @setEvalBranchQuota(1_000_000);
    var found: []const types.Member = &.{};
    var seen: []const type = &.{};

    walk(Root, &found, &seen);
    return found;
} }

fn walk(comptime T: type, comptime found: *[]const types.Member, comptime seen: *[]const type) void {
    for (seen.*) |s| if (s == T) return;
    seen.* = seen.* ++ &[_]type{T};

    const decls = switch (@typeInfo(T)) {
        .@"struct" => |s| s.decl_names,
        .@"union" => |u| u.decl_names,
        .@"enum" => |e| e.decl_names,
        .@"opaque" => |o| o.decl_names,
        else => return,
    };

    inline for (decls) |d| {
        if (comptime std.mem.eql(u8, d, "api")) {
            collect(@field(T, "api"), found);
        } else if (comptime !isSkipped(d)) {
            if (@TypeOf(@field(T, d)) == type) {
                walk(@field(T, d), found, seen);
            }
        }
    }
}

fn isSkipped(comptime name: []const u8) bool {
    inline for (skip) |s| if (std.mem.eql(u8, s, name)) return true;
    return false;
}

fn collect(comptime v: anytype, comptime found: *[]const types.Member) void {
    const V = @TypeOf(v);
    if (V == types.Member) {
        found.* = found.* ++ &[_]types.Member{v};
    } else switch (@typeInfo(V)) {
        .@"struct" => |s| if (s.is_tuple) inline for (v) |x| collect(x, found),
        .array => inline for (v) |x| collect(x, found),
        .pointer => inline for (v.*) |x| collect(x, found),

        else => @compileError(std.fmt.comptimePrint("`api` must be a Member or a tuple/array of them, got {s} instead.", .{ @typeName(V) })),
    }
}