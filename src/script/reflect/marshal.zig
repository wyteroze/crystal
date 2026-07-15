// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;

// set by ScriptEngine
pub var allocator: std.mem.Allocator = undefined;
pub var ref_allocator: std.mem.Allocator = undefined;

fn isRefType(comptime T: type) bool {
    return @typeInfo(T) == .@"struct" and @hasDecl(T, "lua_ref") and T.lua_ref;
}

pub fn Handle(comptime T: type) type {
    return struct {
        pub const HandleTarget = T;
        ptr: *T
    };
}

pub fn push(l: *Lua, value: anytype) void {
    const Type = @TypeOf(value);

    switch (@typeInfo(Type)) {
        .void => @panic("cannot push void"),
        .bool => l.pushBoolean(value),
        .int, .comptime_int => l.pushInteger(@intCast(value)),
        .float, .comptime_float => l.pushNumber(@floatCast(value)),
        .@"fn" => l.pushFunction(zlua.wrap(wrapFunc(value))),
        .@"enum" => _ = l.pushStringZ(@tagName(value)),
        .pointer => |p| if (comptime isString(p)) { _ = l.pushString(value); } else @compileError("non-string pointers not supported, but got " ++ @typeName(Type)),
        .optional, .null => if (value == null) l.pushNil() else push(l, value.?),
        .error_union => if (value) |v| push(l, v) else |e| {
            l.raiseErrorStr("%s", .{ @errorName(e).ptr });
        },
        .vector => |v| {
            l.createTable(v.len, 0);
            inline for (0..v.len) |i| {
                push(l, value[i]);
                l.setIndexRaw(-2, @intCast(i + 1));
            }
        },
        else => {
            if (comptime isHandle(Type)) {
                const Target = Type.HandleTarget;
                const ud = l.newUserdata(*Target, 0);
                ud.* = value.ptr;

                l.setMetatableRegistry(optionalName(Target));
            } else if (comptime isRefType(Type)) {
                const boxed = ref_allocator.create(Type) catch l.raiseErrorStr("out of memory", .{});
                boxed.* = value;

                const ud = l.newUserdata(*Type, 0);
                ud.* = boxed;
                l.setMetatableRegistry(optionalName(Type));
            } else {
                const ud = l.newUserdata(Type, 0);
                ud.* = value;

                l.setMetatableRegistry(optionalName(Type));
            }
        }
    }
}

pub fn check(l: *Lua, comptime T: type, idx: i32) !T {
    const starting_stack = l.getTop();
    defer { if (l.getTop() != starting_stack) @panic("unbalanced stack"); }

    switch (@typeInfo(T)) {
        .void => @panic("cannot check void"),
        .bool => return l.toBoolean(idx),
        .int => return @as(T, @intCast(try l.toInteger(idx))),
        .float => return @as(T, @floatCast(try l.toNumber(idx))),
        .pointer => |p| {
            if (comptime isString(p)) {
                if (p.is_const) return try l.toString(idx);
                return try allocator.dupe(u8, try l.toString(idx));
            }
            if (p.size == .one) {
                const Child = p.child;
                if (comptime isRefType(Child)) return (try checkBox(l, Child, idx));
                return l.checkUserdata(Child, idx, optionalName(Child));
            }

            @compileError("non-string pointers not supported");
        },
        .optional => |o| {
            if (l.isNil(idx)) return null;
            return try check(l, o.child, idx);
        },
        .@"enum" => |e| {
            const name = try check(l, []const u8, idx);
            inline for (e.fields) |f| {
                if (std.mem.eql(u8, name, f.name)) {
                    return @field(T, f.name);
                }
            }

            return error.InvalidEnumTag;
        },
        .vector => |a| {
            var result: [a.len]a.child = undefined;
            l.pushValue(idx);
            defer l.pop(1);

            for (0..a.len) |i| {
                _ = l.getIndexRaw(-1, @intCast(i+1));
                defer l.pop(1);

                result[i] = try check(l, a.child, -1);
            }

            return result;
        },

        else => {
            if (comptime isHandle(T)) {
                const Target = T.HandleTarget;
                if (comptime isRefType(Target)) return .{ .ptr = try checkBox(l, Target, idx) };

                return .{ .ptr = l.checkUserdata(Target, idx, optionalName(Target)) };
            }

            if (comptime isCallback(T)) {
                l.pushValue(idx);
                const ref = l.ref(zlua.registry_index);

                return .{ .lua = l, .ref = ref };
            }

            if (comptime isRefType(T)) return (try checkBox(l, T, idx)).*;
            return l.checkUserdata(T, idx, optionalName(T)).*;
        }
    }
}

pub fn wrapFunc(comptime func: anytype) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const Func = @TypeOf(func);
            const func_info = @typeInfo(Func).@"fn";
            const params = func_info.params;
            const Self = switch (@typeInfo(params[0].type.?)) {
                .pointer => |p| p.child,
                else => params[0].type.?
            };
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
                args[i] = check(l, ParamType, i+1) catch |e| l.raiseErrorStr("%s", .{ @errorName(e).ptr });
            }

            const result = @call(.auto, func, args);
            if (@typeInfo(ReturnType) == .error_union) {
                if (result) |r| {
                    if (Payload == void)  return 0;

                    push(l, r);
                    return 1;
                } else |e| {
                    if (@hasField(Self, "diagnostic")) {
                        const self = switch (@typeInfo(params[0].type.?)) {
                            .pointer => args[0],
                            else => &args[0]
                        };

                        l.raiseErrorStr("%s", .{ self.diagnostic.message.ptr });
                        unreachable;
                    } else {
                        l.raiseErrorStr("%s", .{ @errorName(e).ptr });
                        unreachable;
                    }
                }
            }

            if (Payload != void) push(l, result);
            return (if (Payload == void) 0 else 1);
        }
    }.c;
}

pub fn wrapModuleFunc(comptime Lib: type, comptime func: anytype) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const Func = @TypeOf(func);
            const func_info = @typeInfo(Func).@"fn";
            const params = func_info.params;
            const has_self = if (params.len > 0) switch (@typeInfo(params[0].type.?)) {
                .pointer => |p| p.child == Lib,
                else => params[0].type.? == Lib,
            } else false;
            const Self = Lib;

            const ReturnType = func_info.return_type orelse void;
            const Payload = switch (@typeInfo(ReturnType)) {
                .error_union => |eu| eu.payload,
                else => ReturnType
            };

            var args: std.meta.ArgsTuple(Func) = undefined;

            const SelfPtr = if (has_self) *Self else void;
            var self_ptr: SelfPtr = undefined;
            if (has_self) {
                self_ptr = l.toUserdata(Self, Lua.upvalueIndex(1)) catch l.raiseErrorStr("module self upvalue is missing", .{});
                args[0] = switch (@typeInfo(params[0].type.?)) {
                    .pointer => self_ptr,
                    else => self_ptr.*
                };
            }

            const arg_start = if (has_self) 1 else 0;
            inline for (params[arg_start..], 0..) |p, offset| {
                const i = arg_start + offset;
                const ParamType = p.type.?;

                args[i] = check(l, ParamType, offset + 1) catch |e| l.raiseErrorStr("%s", .{ @errorName(e).ptr });
            }

            const result = @call(.auto, func, args);
            if (@typeInfo(ReturnType) == .error_union) {
                if (result) |r| {
                    if (Payload == void)  return 0;

                    push(l, r);
                    return 1;
                } else |e| {
                    if (@hasField(Self, "diagnostic")) {
                        l.raiseErrorStr("%s", .{ self_ptr.diagnostic.message.ptr });
                        unreachable;
                    } else {
                        l.raiseErrorStr("%s", .{ @errorName(e).ptr });
                        unreachable;
                    }
                }
            }

            if (Payload != void) push(l, result);
            return (if (Payload == void) 0 else 1);
        }
    }.c;
}

pub fn wrapIndex(comptime Lib: type, name: [:0]const u8) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const self = getSelf(l, Lib, 1, name);
            const key = l.checkString(2);

            inline for (comptime std.meta.fields(Lib)) |f| {
                if (comptime isHidden(Lib, f.name)) continue;
                if (std.mem.eql(u8, f.name, key)) {
                    push(l, @field(self.*, f.name));
                    return 1;
                }
            }

            inline for (comptime std.meta.declarations(Lib)) |d| {
                if (comptime isHidden(Lib, d.name)) continue;

                // W zig
                const is_getter = comptime (d.name.len > 3 and d.name[0] == 'g' and d.name[1] == 'e' and d.name[2] == 't');
                if (is_getter) {
                    const field = comptime d.name[3..];

                    if (std.mem.eql(u8, key, field)) {
                        const getter = @field(Lib, d.name);
                        const result = @call(.auto, getter, .{ self.* });
                        push(l, result);
                        return 1;
                    }
                }

                if (comptime @hasDecl(Lib, "operators")) {
                    inline for (comptime std.meta.fields(@TypeOf(Lib.operators))) |op_field| {
                        if (comptime std.mem.eql(u8, "unm", op_field.name)) continue;
                        const capitalized = comptime capitalizeFirst(op_field.name);
                        if (std.mem.eql(u8, key, capitalized)) {
                            const fn_name = @field(Lib.operators, op_field.name);
                            const op_fn = @field(Lib, fn_name);
                            l.pushFunction(zlua.wrap(wrapInPlaceOp(Lib, op_fn)));
                            return 1;
                        }
                    }
                }

                if (std.mem.eql(u8, d.name, key)) {
                    const decl = @field(Lib, d.name);
                    if (@typeInfo(@TypeOf(decl)) == .@"fn") {
                        l.pushFunction(zlua.wrap(wrapFunc(decl)));
                        return 1;
                    }
                }
            }

            l.pushNil();
            return 1;
        }
    }.c;
}

pub fn wrapModuleIndex(comptime Lib: type, name: [:0]const u8) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const self = l.checkUserdata(Lib, 1, name);
            const key = l.checkString(2);

            inline for (comptime std.meta.fields(Lib)) |f| {
                if (comptime isHidden(Lib, f.name)) continue;
                if (std.mem.eql(u8, f.name, key)) {
                    push(l, @field(self.*, f.name));
                    return 1;
                }
            }

            inline for (comptime std.meta.declarations(Lib)) |d| {
                if (comptime isHidden(Lib, d.name)) continue;
                if (std.mem.eql(u8, d.name, key)) {
                    const decl = @field(Lib, d.name);

                    if (@typeInfo(@TypeOf(decl)) == .@"fn") {
                        l.pushLightUserdata(self);
                        l.pushClosure(zlua.wrap(wrapModuleFunc(Lib, decl)), 1);
                        return 1;
                    }
                }
            }

            l.pushNil();
            return 1;
        }
    }.c;
}

pub fn wrapNewIndex(comptime Lib: type, name: [:0]const u8) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const self = getSelf(l, Lib, 1, name);
            const key = l.checkString(2);

            inline for (std.meta.fields(Lib)) |f| {
                if (comptime isHidden(Lib, f.name)) continue;
                if (std.mem.eql(u8, f.name, key)) {
                    @field(self.*, f.name) = check(l, f.type, 3) catch |e| l.raiseErrorStr("%s", .{ @errorName(e).ptr });
                }
            }

            inline for (comptime std.meta.declarations(Lib)) |d| {
                if (comptime isHidden(Lib, d.name)) continue;

                const is_setter = comptime (d.name.len > 3 and d.name[0] == 's' and d.name[1] == 'e' and d.name[2] == 't');
                if (is_setter) {
                    const field = comptime d.name[3..];
                    if (std.mem.eql(u8, key, field)) {
                        const setter = @field(Lib, d.name);
                        const Setter = @TypeOf(setter);
                        const params = @typeInfo(Setter).@"fn".params;
                        const ValueType = params[1].type.?;

                        const value = check(l, ValueType, 3) catch |e| l.raiseErrorStr("%s", .{ @errorName(e).ptr });
                        const result = @call(.auto, setter, .{ self, value });
                        const Result = @TypeOf(result);

                        switch (@typeInfo(Result)) {
                            .void => return 0,
                            .error_union => {
                                if (result) {
                                    return 0;
                                } else |err| {
                                    l.raiseErrorStr("%s", .{ @errorName(err).ptr });
                                    unreachable;
                                }
                            },
                            else => @compileError("setter function returns " ++ @typeName(Result) ++ ", but they may only return void or an error union")
                        }
                    }
                }
            }

            l.raiseErrorStr("attempt to set unknown or read only field '%s'", .{ key.ptr });
        }
    }.c;
}

pub fn wrapGc(comptime Lib: type, name: [:0]const u8) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const self = l.checkUserdata(Lib, 1, name);
            self.deinit();

            return 0;
        }
    }.c;
}

pub fn wrapToString(comptime T: type) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const self = check(l, T, 1) catch |e| l.raiseErrorStr("%s", .{ @errorName(e).ptr });

            var buf: [128]u8 = undefined;
            var writer = std.Io.Writer.fixed(&buf);
            self.format(&writer) catch |e|
                l.raiseErrorStr("failed to format %s: %s", .{ trimmedName(T).ptr, @errorName(e).ptr });

            _ = l.pushString(writer.buffered());
            return 1;
        }
    }.c;
}

pub fn wrapOps(l: *Lua, comptime T: type) void {
    inline for (comptime std.meta.fields(@TypeOf(T.operators))) |f| {
        if (!comptime isValidOpName(f.name)) continue;
        const op_name = @field(T.operators, f.name);
        const func = @field(T, op_name);

        l.pushFunction(zlua.wrap(wrapFunc(func)));
        l.setField(-2, "__" ++ f.name);
    }
}

fn isString(typeinfo: std.builtin.Type.Pointer) bool {
    const childinfo = @typeInfo(typeinfo.child);
    if ((typeinfo.child == u8 and typeinfo.size != .one) or (typeinfo.size == .one and childinfo == .array and childinfo.array.child == u8)) {
        return true;
    }

    return false;
}

fn trimmedName(comptime T: type) [:0]const u8 {
    const full = @typeName(T);
    const pos = std.mem.findScalarLast(u8, full, '.')
        orelse return full;

    return full[pos+1..];
}

fn isHidden(comptime T: type, comptime name: [:0]const u8) bool {
    if (std.mem.eql(u8, "allocator", name) or
        std.mem.eql(u8, "io", name) or
        std.mem.eql(u8, "init", name) or
        std.mem.eql(u8, "deinit", name) or
        std.mem.eql(u8, "name", name) or
        std.mem.eql(u8, "format", name)
    ) return true;

    if (!@hasDecl(T, "hidden")) return false;
    inline for (T.hidden) |nm| {
        if (std.mem.eql(u8, nm, name)) return true;
    }

    return false;
}

fn isValidOpName(comptime name: [:0]const u8) bool {
    if (std.mem.eql(u8, "add", name) or
        std.mem.eql(u8, "sub", name) or
        std.mem.eql(u8, "mul", name) or
        std.mem.eql(u8, "div", name) or
        std.mem.eql(u8, "mod", name) or
        std.mem.eql(u8, "pow", name) or
        std.mem.eql(u8, "idiv", name) or
        std.mem.eql(u8, "unm", name)
    ) return true;

    return false;
}

fn capitalizeFirst(comptime str: [:0]const u8) [:0]const u8 {
    if (str.len == 0) return str;

    comptime var buf: [str.len:0]u8 = undefined;
    @memcpy(&buf, str);
    buf[0] = std.ascii.toUpper(buf[0]);

    const final = buf;
    return &final;
}

fn wrapInPlaceOp(comptime Lib: type, comptime op_fn: anytype) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const self = getSelf(l, Lib, 1, Lib.name);
            const other = getSelf(l, Lib, 2, Lib.name);
            self.* = @call(.auto, op_fn, .{ self.*, other.* });

            return 0;
        }
    }.c;
}

fn isHandle(comptime T: type) bool {
    return @typeInfo(T) == .@"struct" and @hasDecl(T, "HandleTarget");
}

fn isCallback(comptime T: type) bool {
    return @typeInfo(T) == .@"struct" and @hasDecl(T, "LuaCallback");
}

fn optionalName(comptime T: type) [:0]const u8 {
    if (@hasDecl(T, "name")) return @field(T, "name");
    if (@hasDecl(T, "lua_name")) return @field(T, "lua_name");

    return trimmedName(T);
}

fn checkBox(l: *Lua, comptime T: type, idx: i32) !*T {
    return l.checkUserdata(*T, idx, optionalName(T)).*;
}

fn getSelf(l: *Lua, comptime Lib: type, idx: i32, name: [:0]const u8) *Lib {
    if (comptime isRefType(Lib)) return l.checkUserdata(*Lib, idx, name).*;
    return l.checkUserdata(Lib, idx, name);
}
