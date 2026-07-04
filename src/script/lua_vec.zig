// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const shared = @import("shared.zig");
const types = @import("../types.zig");
const Lua = zlua.Lua;
const Vec2_SIMD = types.Vec2_SIMD;
const Vec3_SIMD = types.Vec3_SIMD;
const LuaTypeTag = shared.LuaTypeTag;

fn VecRef(comptime T: type) type {
    return union(enum) {
        value: T,
        ptr: *T,

        pub fn get(self: @This()) T {
            return switch (self) {
                .value => |v| v,
                .ptr => |p| p.*,
            };
        }

        pub fn set(self: *@This(), v: T) void {
            switch (self.*) {
                .value => self.* = .{ .value = v },
                .ptr => |p| p.* = v,
            }
        }
    };
}

pub const Vec3Ref = VecRef(Vec3_SIMD);
pub const Vec2Ref = VecRef(Vec2_SIMD);

const vec3Lib = [_]zlua.FnReg{
    .{ .name = "new", .func = zlua.wrap(vec3New) }
};

const vec3Methods = [_]zlua.FnReg{
    // methods
    .{ .name = "Add", .func = zlua.wrap(vec3Add) },
    .{ .name = "Sub", .func = zlua.wrap(vec3Subtract) },
    .{ .name = "Mul", .func = zlua.wrap(vec3Multiply) },
    .{ .name = "Div", .func = zlua.wrap(vec3Divide) },

    // metamethods
    .{ .name = "__add", .func = zlua.wrap(vec3Add) },
    .{ .name = "__sub", .func = zlua.wrap(vec3Subtract) },
    .{ .name = "__mul", .func = zlua.wrap(vec3Multiply) },
    .{ .name = "__div", .func = zlua.wrap(vec3Divide) }
};

const vec2Lib = [_]zlua.FnReg{
    .{ .name = "new", .func = zlua.wrap(vec2New) }
};

const vec2Methods = [_]zlua.FnReg{
    // methods
    .{ .name = "Add", .func = zlua.wrap(vec2Add) },
    .{ .name = "Sub", .func = zlua.wrap(vec2Subtract) },
    .{ .name = "Mul", .func = zlua.wrap(vec2Multiply) },
    .{ .name = "Div", .func = zlua.wrap(vec2Divide) },

    // metamethods
    .{ .name = "__add", .func = zlua.wrap(vec2Add) },
    .{ .name = "__sub", .func = zlua.wrap(vec2Subtract) },
    .{ .name = "__mul", .func = zlua.wrap(vec2Multiply) },
    .{ .name = "__div", .func = zlua.wrap(vec2Divide) }
};

// Vec3
fn vec3New(l: *Lua) i32 {
    const x = @as(f32, @floatCast(l.toNumber(1) catch 0));
    const y = @as(f32, @floatCast(l.toNumber(2) catch 0));
    const z = @as(f32, @floatCast(l.toNumber(3) catch 0));
    const vec = l.newUserdata(Vec3Ref, 0);
    vec.* = .{ .value = Vec3_SIMD { x, y, z } };

    l.setMetatableRegistry("Vec3");
    return 1;
}

fn vec3Get(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3Ref, 1, "Vec3");
    const vec = self.get();

    const key = l.checkString(2);
    if (std.mem.eql(u8, key, "x")) {
        l.pushNumber(vec[0]);
        return 1;
    } else if (std.mem.eql(u8, key, "y")) {
        l.pushNumber(vec[1]);
        return 1;
    } else if (std.mem.eql(u8, key, "z")) {
        l.pushNumber(vec[2]);
        return 1;
    }

    _ = l.getMetatableRegistry("Vec3");
    l.pushValue(2);
    _ = l.getTableRaw(-2);
    return 1;
}

fn vec3Set(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3Ref, 1, "Vec3");
    var vec = self.get();

    const key = l.checkString(2);
    const value = @as(f32, @floatCast(l.toNumber(3) catch 0));

    if (std.mem.eql(u8, key, "x")) {
        vec[0] = value;
        self.set(vec);
    } else if (std.mem.eql(u8, key, "y")) {
        vec[1] = value;
        self.set(vec);
    } else if (std.mem.eql(u8, key, "z")) {
        vec[2] = value;
        self.set(vec);
    } else {
        l.raiseErrorStr("invalid field '%s'", .{key.ptr});
    }

    return 0;
}

fn vec3Add(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3Ref, 1, "Vec3");
    const other = l.checkUserdata(Vec3Ref, 2, "Vec3");
    self.set(self.get() + other.get());

    l.pushValue(1);
    return 1;
}

fn vec3Subtract(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3Ref, 1, "Vec3");
    const other = l.checkUserdata(Vec3Ref, 2, "Vec3");
    self.set(self.get() - other.get());

    l.pushValue(1);
    return 1;
}

fn vec3Multiply(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3Ref, 1, "Vec3");
    const other = l.checkUserdata(Vec3Ref, 2, "Vec3");
    self.set(self.get() * other.get());

    l.pushValue(1);
    return 1;
}

fn vec3Divide(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3Ref, 1, "Vec3");
    const other = l.checkUserdata(Vec3Ref, 2, "Vec3");
    self.set(self.get() / other.get());

    l.pushValue(1);
    return 1;
}

fn vec3String(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3Ref, 1, "Vec3");
    const vec = self.get();

    var buf: [96]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "({d}, {d}, {d})", .{ vec[0], vec[1], vec[2] }) catch |e|
        l.raiseErrorStr("failed to format (%s)", .{ @errorName(e).ptr });

    _ = l.pushString(str);
    return 1;
}

// Vec2
fn vec2New(l: *Lua) i32 {
    const x = @as(f32, @floatCast(l.toNumber(1) catch 0));
    const y = @as(f32, @floatCast(l.toNumber(2) catch 0));
    const vec = l.newUserdata(Vec2Ref, 0);
    vec.* = .{ .value = Vec2_SIMD { x, y } };

    l.setMetatableRegistry("Vec2");
    return 1;
}

fn vec2Add(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2Ref, 1, "Vec2");
    const other = l.checkUserdata(Vec2Ref, 2, "Vec2");
    self.set(self.get() + other.get());

    l.pushValue(1);
    return 1;
}

fn vec2Subtract(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2Ref, 1, "Vec2");
    const other = l.checkUserdata(Vec2Ref, 2, "Vec2");
    self.set(self.get() - other.get());

    l.pushValue(1);
    return 1;
}

fn vec2Multiply(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2Ref, 1, "Vec2");
    const other = l.checkUserdata(Vec2Ref, 2, "Vec2");
    self.set(self.get() * other.get());

    l.pushValue(1);
    return 1;
}

fn vec2Divide(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2Ref, 1, "Vec2");
    const other = l.checkUserdata(Vec2Ref, 2, "Vec2");
    self.set(self.get() / other.get());

    l.pushValue(1);
    return 1;
}


fn vec2Get(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2Ref, 1, "Vec2");
    const vec = self.get();
    const key = l.checkString(2);

    if (std.mem.eql(u8, key, "x")) {
        l.pushNumber(vec[0]);
        return 1;
    } else if (std.mem.eql(u8, key, "y")) {
        l.pushNumber(vec[1]);
        return 1;
    }

    _ = l.getMetatableRegistry("Vec2");
    l.pushValue(2);
    _ = l.getTableRaw(-2);
    return 1;
}

fn vec2Set(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2Ref, 1, "Vec2");
    var vec = self.get();
    const key = l.checkString(2);
    const value = @as(f32, @floatCast(l.toNumber(3) catch 0));

    if (std.mem.eql(u8, key, "x")) {
        vec[0] = value;
        self.set(vec);
    } else if (std.mem.eql(u8, key, "y")) {
        vec[1] = value;
        self.set(vec);
    } else {
        l.raiseErrorStr("invalid field '%s'", .{key.ptr});
    }

    return 0;
}

fn vec2String(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2Ref, 1, "Vec2");
    const vec = self.get();

    var buf: [64]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "({d}, {d})", .{ vec[0], vec[1] }) catch |e|
        l.raiseErrorStr("failed to format (%s)", .{ @errorName(e).ptr });

    _ = l.pushString(str);
    return 1;
}

pub fn pushVec3(l: *Lua, v: Vec3_SIMD) void {
    const vec = l.newUserdata(Vec3_SIMD, 0);
    vec.* = v;

    l.setMetatableRegistry("Vec3");
}

pub fn pushVec3Ref(l: *Lua, ptr: *Vec3_SIMD) void {
    const vec = l.newUserdata(Vec3Ref, 0);
    vec.* = .{ .ptr = ptr };

    l.setMetatableRegistry("Vec3");
}

pub fn checkVec3(l: *Lua, index: i32) Vec3_SIMD {
    const v = l.checkUserdata(Vec3Ref, index, "Vec3");

    return v.get();
}

pub fn register(l: *Lua) !void {
    // Vec3 object
    try l.newMetatable("Vec3");
    l.pushFunction(zlua.wrap(vec3Set));
    l.setField(-2, "__newindex");
    l.pushFunction(zlua.wrap(vec3Get));
    l.setField(-2, "__index");
    l.pushFunction(zlua.wrap(vec3String));
    l.setField(-2, "__tostring");
    l.setFuncs(&vec3Methods, 0);
    l.pop(1);

    // Vec3 library
    l.newTable();
    l.setFuncs(&vec3Lib, 0);
    l.setGlobal("Vec3");

    // Vec2 object
    try l.newMetatable("Vec2");
    l.pushFunction(zlua.wrap(vec2Set));
    l.setField(-2, "__newindex");
    l.pushFunction(zlua.wrap(vec2Get));
    l.setField(-2, "__index");
    l.pushFunction(zlua.wrap(vec2String));
    l.setField(-2, "__tostring");
    l.setFuncs(&vec2Methods, 0);
    l.pop(1);

    // Vec2 library
    l.newTable();
    l.setFuncs(&vec2Lib, 0);
    l.setGlobal("Vec2");
}
