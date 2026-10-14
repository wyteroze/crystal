// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const names = @import("names.zig");
const types = @import("types.zig");
const signal = @import("signal.zig");

pub fn Marshal(comptime Reg: type) type {
    return struct {
        pub fn parse(comptime T: type, l: *zlua.Lua, idx: i32) T {
            @setEvalBranchQuota(1_000_000);
            if (comptime ptrToValue(T)) |V| return parseValue(V, l, idx); 
            if (comptime Reg.kindOf(T)) |k| switch (k) {
                .value => return parseValue(T, l, idx).*,
                .handle => return parseHandle(T, l, idx).*,
                .record => return parseRecord(T, l, idx),
                .variant => return parseUnion(T, shorthandOf(T), l, idx),
                .object => @compileError("Objects are taken by pointer"),
                else => unreachable
            };

            switch (@typeInfo(T)) {
                .bool => { if (!l.isBoolean(idx)) l.typeError(idx, "boolean"); return l.toBoolean(idx); },
                .int => { if (!l.isNumber(idx)) l.typeError(idx, "integer"); return @intCast(l.toInteger(idx) catch unreachable); },
                .float => { if (!l.isNumber(idx)) l.typeError(idx, "number"); return @floatCast(l.toNumber(idx) catch unreachable); },
                .optional => |o| return if (l.isNoneOrNil(idx)) null else parse(o.child, l, idx),
                .@"enum" => return parseEnum(T, l, idx),
                .@"union" => return parseUnion(T, null, l, idx),
                .pointer => return parseString(T, l, idx), 
                .@"struct" => return parseRecord(T, l, idx),
                else => @compileError(std.fmt.comptimePrint("Type {s} cannot be marshalled from Lua", .{ @typeName(T) }))
            }
        }

        pub fn push(l: *zlua.Lua, v: anytype) void {
            @setEvalBranchQuota(1_000_000);

            const T = @TypeOf(v);
            if (comptime Reg.kindOf(T)) |k| switch (k) {
                .value => return pushValue(l, v),
                .handle => return pushHandle(l, v),
                .record => return pushRecord(T, l, v),
                .variant => return pushUnion(l, v, if (Reg.recipeOf(T).push_shorthand) shorthandOf(T) else null),
                else => unreachable,
            };

            if (comptime signalOf(T)) |Sig| return pushHandle(l, signal.Handle(Sig){ .signal = v });
            switch (@typeInfo(T)) {
                .bool => l.pushBoolean(v),
                .int, .comptime_int => l.pushInteger(@intCast(v)),
                .float, .comptime_float => l.pushNumber(@floatCast(v)),
                .optional => if (v) |x| push(l, x) else l.pushNil(),
                .@"enum" => switch (v) { inline else => |t| _ = l.pushStringZ(comptime names.pascal(@tagName(t))) },
                .@"union" => return pushUnion(l, v, null),
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

        fn ptrToValue(comptime T: type) ?type {
            const info = @typeInfo(T);
            if (info != .pointer or info.pointer.size != .one) return null;

            const C = info.pointer.child;
            return if (Reg.kindOf(C) == .value) C else null;
        }

        fn signalOf(comptime T: type) ?type {
            const info = @typeInfo(T);
            if (info != .pointer or info.pointer.size != .one) return null;

            const C = info.pointer.child;
            return if (@typeInfo(C) == .@"struct" and @hasDecl(C, "Args") and @hasDecl(C, "rawConnect")) C else null;
        }

        fn parseEnum(comptime T: type, l: *zlua.Lua, idx: i32) T {
            const map: std.StaticStringMap(T) = comptime blk: {
                const info = @typeInfo(T).@"enum";
                var kv: [info.field_names.len]struct { []const u8, T } = undefined;
                for (info.field_names, 0..) |nm, i| kv[i] = .{ names.pascal(nm), @enumFromInt(info.field_values[i]) };

                break :blk .initComptime(kv);
            };
            if (l.typeOf(idx) != .string) l.raiseErrorStr("arg {d}: expected {s} (string), got {s}", .{ idx, @typeName(T).ptr, @tagName(l.typeOf(idx)).ptr });

            const s = l.toString(idx) catch unreachable;
            return map.get(s) orelse l.raiseErrorStr("arg {d}: '{s}' is not a valid {s}", .{ idx, s.ptr, @typeName(T).ptr });
        }

        fn shorthandOf(comptime T: type) ?[]const u8 {
            return if (Reg.recipeOf(T).number) |v| @tagName(v) else null;
        }

        fn parseUnion(comptime T: type, comptime number: ?[]const u8, l: *zlua.Lua, idx: i32) T {
            const info = @typeInfo(T).@"union";

            switch (l.typeOf(idx)) {
                .number => {
                    if (number) |nm| return @unionInit(T, nm, parse(@FieldType(T, nm), l, idx));
                    l.raiseErrorStr("arg %d: %s does not accept a bare number", .{ idx, @typeName(T).ptr });
                },
                .string => {
                    const s = l.toString(idx) catch unreachable;
                    inline for (info.field_names, 0..) |nm, i| {
                        if (info.field_types[i] == void and std.mem.eql(u8, s, comptime names.pascal(nm)))
                            return @unionInit(T, nm, {});
                    }

                    l.raiseErrorStr("arg {d}: '{s}' is not a valid {s} variant", .{ idx, s.ptr, @typeName(T).ptr });
                },
                .table => {
                    const abs = l.absIndex(idx);
                    var result: ?T = null;

                    inline for (info.field_names, 0..) |nm, i| {
                        if (info.field_types[i] != void) {
                            const name = comptime names.pascal(nm);
                            if (l.getField(abs, name) != .nil) {
                                if (result != null)
                                    l.raiseErrorStr("arg {d}: {s} table must have exactly one variant key", .{ idx, @typeName(T).ptr });
                                result = @unionInit(T, nm, parse(info.field_types[i], l, -1));
                            }
                            l.pop(1);
                        }
                    }

                    return result orelse
                        l.raiseErrorStr("arg %d: table is not a valid %s (no known variant key)", .{ idx, @typeName(T).ptr });
                },
                else => l.raiseErrorStr("arg %d: expected %s (string or table), got %s", .{ idx, @typeName(T).ptr, @tagName(l.typeOf(idx)).ptr }),
            }
        }

        fn parseString(comptime T: type, l: *zlua.Lua, idx: i32) T {
            comptime {
                const p = @typeInfo(T).pointer;
                if (p.size != .slice or p.child != u8) @compileError("unsupported pointer type " ++ @typeName(T));
            }

            if (!l.isString(idx)) l.typeError(idx, @tagName(l.typeOf(idx)));
            return l.toString(idx) catch unreachable;
        }

        fn parseRecord(comptime T: type, l: *zlua.Lua, idx: i32) T {
            const t = l.absIndex(idx);
            if (l.typeOf(t) != .table) l.raiseErrorStr("expected a table for %s", .{ @typeName(T).ptr });
            const info = @typeInfo(T).@"struct";

            var out: T = .{};
            inline for (info.field_names, 0..) |nm, i| {
                const key = comptime names.pascal(nm);
                const ty = l.getField(t, key);
                defer l.pop(1);

                if (ty != .nil) @field(out, nm) = parse(info.field_types[i], l, -1);
            }

            l.pushNil();
            while (l.next(t)) {
                if (l.typeOf(-2) != .string) l.raiseErrorStr("%s: field names must be strings", .{ @typeName(T).ptr });

                const key = l.toString(-2) catch unreachable;
                var known = false;
                inline for (info.field_names) |nm| {
                    if (std.mem.eql(u8, key, comptime names.pascal(nm))) known = true;
                }

                if (!known)
                    l.raiseErrorStr("%s: unknown field '%s'", .{ @typeName(T).ptr, key.ptr });

                l.pop(1);
            }

            return out;
        }

        fn pushRecord(comptime T: type, l: *zlua.Lua, v: T) void {
            l.newTable();

            const info = @typeInfo(T).@"struct";
            inline for (info.field_names) |nm| {
                push(l, @field(v, nm));
                l.setField(-2, comptime names.pascal(nm));
            }
        }

        fn pushUnion(l: *zlua.Lua, v: anytype, comptime number: ?[]const u8) void {
            switch (v) {
                inline else => |payload, tag| {
                    const name = comptime names.pascal(@tagName(tag));
                    if (number != null and comptime std.mem.eql(u8, @tagName(tag), number.?)) {
                        push(l, payload);
                    } else if (@TypeOf(payload) == void) {
                        _ = l.pushStringZ(name);
                    } else {
                        l.createTable(0, 1);
                        push(l, payload);
                        l.setField(-2, name);
                    }
                },
            }
        }

        fn parseHandle(comptime T: type, l: *zlua.Lua, idx: i32) *T {
            return l.toUserdataTagged(T, idx, @intCast(Reg.tagOf(T))) catch l.typeError(idx, names.shortTypeName(T));
        }

        fn pushHandle(l: *zlua.Lua, v: anytype) void {
            const T = @TypeOf(v);
            const tag = Reg.tagOf(T);
            const p = l.newUserdataTagged(T, @intCast(tag));
            p.* = v;

            l.getUserdataMetatable(@intCast(tag));
            _ = l.setMetatable(-2);
        }
    };
}