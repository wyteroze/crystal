// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const util = @import("util.zig");
const binding = @import("binding.zig");
const Lua = zlua.Lua;

const Fn = *const fn (l: *Lua) void;
const LuaFn = *const fn (l: *Lua) i32;

pub const Method = struct {
    name: [:0]const u8,
    push: Fn,

    pub fn named(comptime name: [:0]const u8, comptime func: anytype) Method {
        return .{
            .name = name,
            .push = struct { fn c(l: *Lua) void { util.autoPush(l, func); } }.c
        };
    }

    pub fn custom(comptime name: [:0]const u8, comptime func: anytype) Method {
        return .{
            .name = name,
            .push = struct { fn c(l: *Lua) void { l.pushFunction(zlua.wrap(func)); } }.c
        };
    }

    pub fn nonNamed(comptime func: anytype) Method {
        return .{
            .name = "",
            .push = struct { fn c(l: *Lua) void { util.autoPush(l, func); } }.c
        };
    }
};

pub const Constant = struct {
    name: [:0]const u8,
    push: Fn,

    pub fn named(comptime name: [:0]const u8, comptime val: anytype) Constant {
        return .{
            .name = name,
            .push = struct {
                fn c(l: *Lua) void {
                    const T = @TypeOf(val);
                    if (comptime binding.isBoundType(T)) {
                        binding.pushVal(l, T, val);
                    } else {
                        l.pushAny(val) catch unreachable;
                    }
                }
            }.c
        };
    }
};

pub const Property = struct {
    name: [:0]const u8,
    get: ?Fn = null,
    set: ?Fn = null,

    pub fn Get(comptime name: [:0]const u8, comptime func: anytype) Property {
        return .{
            .name = name,
            .get = struct { fn c(l: *Lua) void { util.autoPush(l, func); } }.c
        };
    }
    pub fn Set(comptime name: [:0]const u8, comptime func: anytype) Property {
        return .{
            .name = name,
            .set = struct { fn c(l: *Lua) void { util.autoPush(l, func); } }.c
        };
    }
    pub fn GetSet(comptime name: [:0]const u8, comptime getter: anytype, comptime setter: anytype) Property {
        return .{
            .name = name,
            .get = struct { fn c(l: *Lua) void { util.autoPush(l, getter); } }.c,
            .set = struct { fn c(l: *Lua) void { util.autoPush(l, setter); } }.c
        };
    }
};

pub const Properties = union(enum) {
    prop_fields: []Property,
    custom_fns: [2]?Fn,
    custom_lua_fns: [2]?LuaFn,

    pub fn fields(f: []Property) Properties {
        return .{ .prop_fields = f };
    }
    pub fn custom(comptime get: anytype, comptime set: anytype) Properties {
        return .{
            .custom_fns = .{
                struct { fn c(l: *Lua) void { util.autoPush(l, get); } }.c,
                struct { fn c(l: *Lua) void { util.autoPush(l, set); } }.c
            }
        };
    }
    pub fn luaCustom(comptime get: fn (l: *Lua) i32, comptime set: fn (l: *Lua) i32) Properties {
        return .{
            .custom_lua_fns = .{ get, set }
        };
    }
};

pub const Scope = union(enum) {
    /// A global accessible in all lua scripts
    global,
    /// A module with the given name that contains the type.
    module: [:0]const u8,
};

pub const OpMode = union(enum) {
    identity,
    custom_fn: Fn,

    pub fn custom(comptime func: anytype) OpMode {
        return .{
            .custom_fn = struct { fn c(l: *Lua) void { util.autoPush(l, func); } }.c
        };
    }

    pub fn raw(comptime func: fn (*Lua) i32) OpMode {
        return .{
            .custom_fn = struct { fn c(l: *Lua) void { l.pushFunction(zlua.wrap(func)); } }.c
        };
    }

    pub fn format(comptime func: anytype) OpMode {
        return .{
            .custom_fn = struct {
                fn c(l: *Lua) void {
                    l.pushFunction(zlua.wrap(struct {
                        fn c(lua: *Lua) i32 {
                            const FuncInfo = @typeInfo(@TypeOf(func)).@"fn";
                            const Self = FuncInfo.params[0].type.?;
                            const SelfInfo = @typeInfo(Self);
                            const Inner = if (SelfInfo == .pointer) SelfInfo.pointer.child else Self;
                            const self = util.parseVal(lua, Self, 1) catch |e| util.luaErr(lua, e);

                            const buf_len = if (@hasDecl(Inner, "__format_len")) Inner.__format_len else 128;
                            var buf: [buf_len]u8 = undefined;
                            const s = func(self, &buf);

                            _ = lua.pushString(s);
                            return 1;
                        }
                    }.c));
                }
            }.c
        };
    }
};
pub const Ops = struct {
    add: ?OpMode = null,
    sub: ?OpMode = null,
    mul: ?OpMode = null,
    div: ?OpMode = null,
    neg: ?OpMode = null,
    eq: ?OpMode = null,
    tostring: ?OpMode = null,
};

pub const Name = union(enum) {
    auto,
    named: [:0]const u8
};

pub const LuaValueRecipe = struct {
    name: Name = .auto,
    scope: Scope = .global,
    constructors: []const Method = &.{},
    constants: []const Constant = &.{},
    methods: []const Method = &.{},
    fields: []const []const u8 = &.{},
    ops: Ops = .{}
};

pub const LuaReferenceRecipe = struct {
    name: Name = .auto,
    scope: Scope = .global,
    constructors: []const Method = &.{},
    properties: ?Properties = null,
    methods: []const Method = &.{},
    eq: OpMode = .identity,
    tostring: OpMode = .identity,
    gc: ?Method = null
};

pub const LuaModuleRecipe = struct {
    name: [:0]const u8,
    functions: []const Method = &.{},
    properties: ?Properties = null
};