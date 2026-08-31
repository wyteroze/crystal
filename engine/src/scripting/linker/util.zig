// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const binding = @import("Binding.zig");
const Lua = zlua.Lua;

pub const parseVal = binding.parseVal;
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

pub fn identityToString(comptime bind: anytype) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const self = bind.check(l, 1);
            var buf: [512]u8 = undefined;

            const s = (if (bind.ref)
                std.fmt.bufPrint(&buf, "{s}(0x{x})", .{ bind.type_name, @intFromPtr(self) })
            else
                std.fmt.bufPrint(&buf, "{s}({any})", .{ bind.type_name, self }))
            catch bind.type_name;

            _ = l.pushString(s);
            return 1;
        }
    }.c;
}

pub fn pascalCase(comptime name: []const u8) [name.len]u8 {
    var buf: [name.len]u8 = undefined;
    buf[0] = std.ascii.toUpper(name[0]);

    if (name.len > 1) @memcpy(buf[1..], name[1..]);
    return buf;
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

pub fn luaErr(l: *Lua, err: anyerror, comptime ctx: anytype) noreturn {
    const errname = @errorName(err);

    if (ctx.len >= 2 and std.mem.find(u8, errname, "Expected") != null) {
        l.raiseErrorStr("expected %s, got %s (%s)", .{ luaTypeName(ctx[0]).ptr, l.typeNameIndex(ctx[1]).ptr, errname.ptr });
    } else {
        l.raiseErrorStr("%s", .{ errname.ptr });
    }
}

pub fn moduleRegister(l: *Lua, mod_path: [:0]const u8, field_name: [:0]const u8) void {
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

    l.pushValue(-3);
    l.setField(-2, field_name);

    l.remove(-2);
    l.pop(1);
}

pub fn registerTopLevelModule(l: *Lua, mod_path: [:0]const u8) void {
    // Get `package.loaded`
    _ = l.getGlobal("package");
    _ = l.getField(-1, "loaded");
    l.remove(-2); // pop `package`, we don't need it

    // move what we're registering to the top of the stack, then set
    l.pushValue(-2);
    l.setField(-2, mod_path);

    l.remove(-1); // now pop `loaded`
    l.pop(1);
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
                    const parsed = lua.toAnyAlloc(ParamType, i + 1) catch |e| luaErr(lua, e, .{ ParamType, i+1 });
                    defer parsed.deinit();

                    args[i] = parsed.value;
                } else {
                    const parsed = lua.toAny(ParamType, i + 1) catch |e| luaErr(lua, e, .{ ParamType, i+1 });
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
