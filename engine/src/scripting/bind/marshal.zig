// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const names = @import("names.zig");
const types = @import("types.zig");

pub fn Marshal(comptime Reg: type) type {
    return struct {
        pub fn parse(comptime T: type, l: *zlua.Lua, idx: i32) T {
            if (comptime Reg.kindOf(T)) |k| switch (k) {
                .value => return parseValue(T, l, idx).*,
                .handle => return parseHandle(T, l, idx),
                .object => @compileError("Objects are taken by pointer"),
                else => unreachable
            };

            switch (@typeInfo(T)) {
                .bool => { if (!l.isBoolean(idx)) l.typeError(idx, "boolean"); return l.toBoolean(idx) catch unreachable; },
                .int => { if (!l.isNumber(idx)) l.typeError(idx, "integer"); return @intCast(l.toInteger(idx) catch unreachable); },
                .float => { if (!l.isNumber(idx)) l.typeError(idx, "number"); return @floatCast(l.toNumber(idx) catch unreachable); },
                .optional => |o| return if (l.isNoneOrNil(idx)) null else parse(o.child, l, idx),
                .@"enum" => return parseEnum(T, l, idx),
                .pointer => return parseString(T, l, idx), 
                .@"struct" => return parseRecord(T, l, idx),
                else => @compileError(std.fmt.comptimePrint("Type {s} cannot be marshalled from Lua", .{ @typeName(T) }))
            }
        }

        pub fn push(l: *zlua.Lua, v: anytype) void {
            const T = @TypeOf(v);
            if (comptime Reg.kindOf(T)) |k| switch (k) {
                .value => return pushValue(l, v),
                .handle => return pushHandle(l, v),
                else => unreachable,
            };

            switch (@typeInfo(T)) {
                .bool => l.pushBoolean(v),
                .int, .comptime_int => l.pushInteger(@intCast(v)),
                .float, .comptime_float => l.pushNumber(@floatCast(v)),
                .optional => if (v) |x| push(l, x) else l.pushNil(),
                .@"enum" => switch (v) { inline else => |t| _ = l.pushStringZ(comptime names.pascal(@tagName(t))) },
                .@"union" => switch (v) {
                    inline else => |payload, tag| {
                        const name = comptime names.pascal(@tagName(tag));
                        if (@TypeOf(payload) == void) _ = l.pushStringZ(name) else {
                            l.createTable(0, 1);
                            push(l, payload);
                            l.setField(-2, name);
                        }
                    },
                },
                .@"struct" => |s| {
                    l.createTable(0, s.field_names.len);
                    inline for (s.field_names) |nm| {
                        push(l, @field(v, nm));
                        l.setField(-2, comptime names.pascal(nm));
                    }
                },
                
                .pointer => if (T == []const u8) { _ = l.pushString(v); } else @compileError(std.fmt.comptimePrint("Cannot marshal pointers to Lua, but got type {s}", .{ @typeName(T) })),
                else => @compileError(std.fmt.comptimePrint("Type {s} cannot be marshalled to Lua", .{ @typeName(T) })),
            }
        }

        fn pushValue(l: *zlua.Lua, v: anytype) void {
            const T = @TypeOf(v);
            const p = l.newUserdataTagged(T, @intCast(Reg.tagOf(T)));
            p.* = v;

            l.getUserdataMetatable(@intCast(Reg.tagOf(T)));
            _ = l.setMetatable(-2);
        }

        fn parseValue(comptime T: type, l: *zlua.Lua, idx: i32) *T {
            return l.toUserdataTagged(T, idx, @intCast(Reg.tagOf(T))) catch l.typeError(idx, names.shortTypeName(T));
        }

        fn parseEnum(comptime T: type, l: *zlua.Lua, idx: i32) T {
            const map = comptime blk: {
                const fs: std.StaticStringMap(T) = @typeInfo(T).@"enum".fields;
                var kv: [fs.len]struct { []const u8, T } = undefined;
                for (fs, 0..) |f, i| kv[i] = .{ names.pascal(f.name), @enumFromInt(f.value) };

                break :blk .initComptime(kv);
            };
            if (l.typeOf(idx) != .string) l.raiseErrorStr("arg {d}: expected {s} (string), got {s}", .{ idx, @typeName(T), @tagName(l.typeOf(idx)) });

            const s = l.toString(idx) catch unreachable;
            return map.get(s) orelse l.raiseErrorStr("arg {d}: '{s}' is not a valid {s}", .{ idx, s, @typeName(T) });
        }

        fn parseString(comptime T: type, l: *zlua.Lua, idx: i32) T {
            comptime {
                const p = @typeInfo(T).pointer;
                if (p.size != .slice or p.child != u8) @compileError("unsupported pointer type " ++ @typeName(T));
            }

            if (!.isString(idx)) l.typeError(idx, @tagName(l.typeOf(idx)));
            return l.toString(idx) catch unreachable;
        }

        fn parseRecord(comptime T: type, _: *zlua.Lua, _: i32, _: *types.Diag) T { @compileError("records are not implemented yet"); }
        fn parseHandle(comptime T: type, _: *zlua.Lua, _: i32, _: *types.Diag) T { @compileError("handles are not implemented yet"); }
        fn pushHandle(_: *zlua.Lua, v: anytype) void { @compileError("handles are not implemented yet: " ++ @typeName(@TypeOf(v))); }
    };
}