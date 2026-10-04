// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const binding = @import("Binding.zig");
const Lua = zlua.Lua;

pub const parseVal = binding.parseVal;
pub const parseValAlloc = binding.parseValAlloc;
pub const pushVal = binding.pushVal;
pub const isBoundType = binding.isBoundType;

pub fn identityEq(comptime bind: anytype) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const a = bind.check(l, 1);
            const b = bind.check(l, 2);

            l.pushBoolean(std.meta.eql(a, b));
            return 1;
        }
    }.c;
}

pub fn pascalCase(comptime name: []const u8) [countPascalLen(name)]u8 {
    var buf: [countPascalLen(name)]u8 = undefined;
    var i: usize = 0;
    var upper_next = true;

    for (name) |c| {
        if (c == '_') {
            upper_next = true;
            continue;
        }
        buf[i] = if (upper_next) std.ascii.toUpper(c) else c;
        upper_next = false;
        i += 1;
    }

    return buf;
}

pub fn snakeCaseFromPascal(comptime E: type, pascal: []const u8) ?E {
    @setEvalBranchQuota(100_000);

    inline for (std.meta.fields(E)) |field| {
        const pascal_name = comptime &pascalCase(field.name);
        if (std.mem.eql(u8, pascal, pascal_name)) {
            return @enumFromInt(field.value);
        }
    }

    return null;
}

fn countPascalLen(comptime name: []const u8) usize {
    var len: usize = 0;
    for (name) |c| {
        if (c != '_') len += 1;
    }
    return len;
}

pub fn parseEnumTag(comptime E: type, name: []const u8) ?E {
    @setEvalBranchQuota(100_000);

    inline for (@typeInfo(E).@"enum".fields) |field| {
        const pascal = comptime pascalCase(field.name);
        if (std.mem.eql(u8, name, &pascal)) {
            return @field(E, field.name);
        }
    }

    return null;
}

pub fn pascalCaseTag(comptime E: type, val: E) []const u8 {
    @setEvalBranchQuota(100_000);

    return switch (val) {
        inline else => |tag| comptime &pascalCase(@tagName(tag)),
    };
}

pub fn shortTypeName(comptime T: type) [:0]const u8 {
    const full = @typeName(T);
    const dot = comptime std.mem.lastIndexOfScalar(u8, full, '.') orelse return full ++ "";

    return full[dot + 1..] ++ "";
}

pub fn luaTypeName(comptime T: type) [:0]const u8 {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => "integer",
        .float, .comptime_float => "number",
        .pointer => "string or table or userdata",
        .vector => |info| luaTypeName(info.child),
        .bool => "boolean",
        .@"enum" => "string",
        .optional, .null => "nil",
        .@"struct", .@"union", .array, .void => "table",
        .@"fn" => "function",
        else => @typeName(T)
    };
}

pub fn luaErr(l: *Lua, err: anyerror, ctx: anytype) noreturn {
    const errname = @errorName(err);

    if (ctx.len >= 2 and std.mem.find(u8, errname, "Expected") != null) {
        l.raiseErrorStr("expected %s, got %s (%s)", .{ luaTypeName(ctx[0]).ptr, l.typeNameIndex(ctx[1]).ptr, errname.ptr });
    } else {
        // If you're getting a `LuaValueNotATable` or similar error here,
        // it may mean that you forgot to define the `pub const __lua = .val/.ref` in your type
        l.raiseErrorStr("%s", .{ errname.ptr });
    }
}

pub fn wrapFormatFunc(comptime func: anytype) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const FuncInfo = @typeInfo(@TypeOf(func)).@"fn";
            const Self = FuncInfo.params[0].type.?;
            const self = parseVal(l, Self, 1) catch |e| std.debug.panic("{s}, {s}", .{ @errorName(e), @typeName(Self) });

            var allocating_writer: std.Io.Writer.Allocating = .init(l.allocator());
            defer allocating_writer.deinit();
            
            func(self, &allocating_writer.writer) catch |e| l.raiseErrorStr("writer failed: %s", .{ @errorName(e).ptr });

            const result = allocating_writer.toOwnedSlice() catch @panic("Out of memory");
            defer l.allocator().free(result);

            _ = l.pushString(result);
            return 1;
        }
    }.c;
} 

pub fn moduleRegister(l: *Lua, mod_path: [:0]const u8, field_name: [:0]const u8) void {
    const v_idx = l.getTop();

    _ = l.getGlobal("package");
    _ = l.getField(-1, "loaded");
    l.remove(-2);

    const mod_type = l.getField(-1, mod_path);
    if (mod_type == .nil) {
        l.pop(1);
        l.newTable();
        l.pushValue(-1);
        l.setField(-3, mod_path);
    }

    l.pushValue(v_idx);
    l.setField(-2, field_name);

    l.setTop(v_idx - 1);
}

pub fn registerTopLevelModule(l: *Lua, mod_path: [:0]const u8) void {
    const v_idx = l.getTop();

    _ = l.getGlobal("package");
    _ = l.getField(-1, "loaded");
    l.remove(-2);

    l.pushValue(v_idx);
    l.setField(-2, mod_path);

    l.setTop(v_idx - 1);
}

pub fn autoPush(l: *Lua, comptime func: anytype) void {
    const info = @typeInfo(@TypeOf(func));
    if (info != .@"fn") {
        @compileLog(info);
        @compileLog(func);
        @compileError("function pointer must be passed");
    }

    l.pushFunction(zlua.wrap(struct {
        fn c(lua: *Lua) i32 {
            const Func = @TypeOf(func);
            const func_info = @typeInfo(Func).@"fn";
            const params = func_info.params;
            const Self = if (params.len > 0) switch (@typeInfo(params[0].type.?)) {
                .pointer => |p| p.child,
                else => params[0].type.?
            } else void;
            // If a function's return type is void, the return_type
            // is actually `null`, so we turn null back into void
            const ReturnType = func_info.return_type orelse void;
            const Payload = switch (@typeInfo(ReturnType)) {
                .error_union => |eu| eu.payload,
                else => ReturnType
            };

            var args: std.meta.ArgsTuple(Func) = undefined;

            inline for (params, 0..) |p, i| {
                const ParamType = p.type.?;
                const param_info = @typeInfo(ParamType);
                const Inner = if (param_info == .pointer) param_info.pointer.child else ParamType;

                if (comptime isBoundType(Inner)) {
                    args[i] = parseVal(lua, ParamType, i + 1) catch |e| luaErr(lua, e, .{ ParamType, i+1 });
                } else if (comptime param_info == .pointer and param_info.pointer.size != .one) {
                    const parsed = parseValAlloc(lua, ParamType, i+1) catch |e| luaErr(lua, e, .{ ParamType, i+1 });
                    defer parsed.deinit();

                    args[i] = parsed.value;
                } else {
                    const parsed = parseVal(lua, ParamType, i+1) catch |e| luaErr(lua, e, .{ ParamType, i+1 });
                    args[i] = parsed;
                }
            }

            const result = @call(.auto, func, args);
            if (@typeInfo(ReturnType) == .error_union) {
                if (result) |r| {
                    if (Payload == void) return 0;
                    if (comptime isBoundType(Payload)) {
                        pushVal(lua, Payload, r);
                    } else {
                        lua.pushAny(r) catch |e| luaErr(lua, e, .{});
                    }

                    return 1;
                } else |e| {
                    if (Self != void and @hasField(Self, "diagnostic")) {
                        const self = switch (@typeInfo(params[0].type.?)) {
                            .pointer => args[0],
                            else => &args[0]
                        };

                        lua.raiseErrorStr("%s", .{ self.diagnostic.message.ptr });
                        unreachable;
                    } else {
                        luaErr(lua, e, .{});
                        unreachable;
                    }
                }
            }

            if (Payload == void) return 0;
            const PayloadInner = if (@typeInfo(Payload) == .pointer) @typeInfo(Payload).pointer.child else Payload;
            if (comptime isBoundType(PayloadInner)) {
                pushVal(lua, Payload, result);
            } else {
                lua.pushAny(result) catch |e| luaErr(lua, e, .{});
            }

            return 1;
        }
    }.c));
}

pub fn pushEnum(l: *zlua.Lua, comptime T: type) void {
    l.newTable();

    inline for (std.meta.fields(T)) |f| {
        const pascalName: [:0]const u8 = pascalCase(f.name) ++ "";
        _ = l.pushStringZ(pascalName); l.setField(-2, pascalName);
    }
}

pub fn luaTableToStruct(l: *zlua.Lua, idx: i32, comptime T: type, default: T) T {
    var str: T = default;

    l.checkType(idx, .table);
    l.pushNil();
    while (l.next(idx)) {
        l.checkType(-2, .string);
        const key = l.toString(-2) catch |e| luaErr(l, e, .{ []const u8, -2 });

        var matched = false;
        inline for (@typeInfo(T).@"struct".fields) |sf| {
            if (std.mem.eql(u8, key, &pascalCase(sf.name))) {
                const val = parseVal(l, sf.type, -1) catch |e| luaErr(l, e, .{});
                @field(str, sf.name) = val;
                matched = true;
            }
        }
        if (!matched) l.raiseErrorStr("unknown field '%s'", .{ key.ptr });

        l.pop(1);
    }

    return str;
}