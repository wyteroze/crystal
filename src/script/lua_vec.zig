// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const shared = @import("shared.zig");
const types = @import("../types.zig");
const Lua = zlua.Lua;
const Vec2_SIMD = types.Vec2_SIMD;
const Vec3_SIMD = types.Vec3_SIMD;
const LuaTypeTag = shared.LuaTypeTag;

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
    const vec = l.newUserdata(Vec3_SIMD, 0);
    vec.* = Vec3_SIMD { x, y, z };

    l.setMetatableRegistry("Vec3");
    return 1;
}

fn vec3Get(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3_SIMD, 1, "Vec3");
    const key = l.checkString(2);
    if (std.mem.eql(u8, key, "x")) {
        l.pushNumber(self.*[0]);
        return 1;
    } else if (std.mem.eql(u8, key, "y")) {
        l.pushNumber(self.*[1]);
        return 1;
    } else if (std.mem.eql(u8, key, "z")) {
        l.pushNumber(self.*[2]);
        return 1;
    }

    _ = l.getMetatableRegistry("Vec3");
    l.pushValue(2);
    _ = l.getTableRaw(-2);
    return 1;
}

fn vec3Set(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3_SIMD, 1, "Vec3");
    const key = l.checkString(2);
    const value = @as(f32, @floatCast(l.toNumber(3) catch 0));

    if (std.mem.eql(u8, key, "x")) {
        self.*[0] = value;
    } else if (std.mem.eql(u8, key, "y")) {
        self.*[1] = value;
    } else if (std.mem.eql(u8, key, "z")) {
        self.*[2] = value;
    } else {
        l.raiseErrorStr("invalid field '%s'", .{key.ptr});
    }

    return 0;
}

fn vec3Add(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3_SIMD, 1, "Vec3");
    const other = l.checkUserdata(Vec3_SIMD, 2, "Vec3");
    self.* = self.* + other.*;

    l.pushValue(1);
    return 1;
}

fn vec3Subtract(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3_SIMD, 1, "Vec3");
    const other = l.checkUserdata(Vec3_SIMD, 2, "Vec3");
    self.* = self.* - other.*;

    l.pushValue(1);
    return 1;
}

fn vec3Multiply(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3_SIMD, 1, "Vec3");
    const other = l.checkUserdata(Vec3_SIMD, 2, "Vec3");
    self.* = self.* * other.*;

    l.pushValue(1);
    return 1;
}

fn vec3Divide(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3_SIMD, 1, "Vec3");
    const other = l.checkUserdata(Vec3_SIMD, 2, "Vec3");
    self.* = self.* / other.*;

    l.pushValue(1);
    return 1;
}

fn vec3String(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3_SIMD, 1, "Vec3");

    var buf: [96]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "({d}, {d}, {d})", .{ self[0], self[1], self[2] }) catch |e|
        l.raiseErrorStr("failed to format (%s)", .{ @errorName(e).ptr });

    _ = l.pushString(str);
    return 1;
}

// Vec2
fn vec2New(l: *Lua) i32 {
    const x = @as(f32, @floatCast(l.toNumber(1) catch 0));
    const y = @as(f32, @floatCast(l.toNumber(2) catch 0));
    const vec = l.newUserdata(Vec2_SIMD, 0);
    vec.* = Vec2_SIMD { x, y };

    l.setMetatableRegistry("Vec2");
    return 1;
}

fn vec2Add(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2_SIMD, 1, "Vec2");
    const other = l.checkUserdata(Vec2_SIMD, 2, "Vec2");
    self.* = self.* + other.*;

    l.pushValue(1);
    return 1;
}

fn vec2Subtract(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2_SIMD, 1, "Vec2");
    const other = l.checkUserdata(Vec2_SIMD, 2, "Vec2");
    self.* = self.* - other.*;

    l.pushValue(1);
    return 1;
}

fn vec2Multiply(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2_SIMD, 1, "Vec2");
    const other = l.checkUserdata(Vec2_SIMD, 2, "Vec2");
    self.* = self.* * other.*;

    l.pushValue(1);
    return 1;
}

fn vec2Divide(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2_SIMD, 1, "Vec2");
    const other = l.checkUserdata(Vec2_SIMD, 2, "Vec2");
    self.* = self.* / other.*;

    l.pushValue(1);
    return 1;
}


fn vec2Get(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2_SIMD, 1, "Vec2");
    const key = l.checkString(2);
    if (std.mem.eql(u8, key, "x")) {
        l.pushNumber(self.*[0]);
        return 1;
    } else if (std.mem.eql(u8, key, "y")) {
        l.pushNumber(self.*[1]);
        return 1;
    }

    _ = l.getMetatableRegistry("Vec2");
    l.pushValue(2);
    _ = l.getTableRaw(-2);
    return 1;
}

fn vec2Set(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2_SIMD, 1, "Vec2");
    const key = l.checkString(2);
    const value = @as(f32, @floatCast(l.toNumber(3) catch 0));

    if (std.mem.eql(u8, key, "x")) {
        self.*[0] = value;
    } else if (std.mem.eql(u8, key, "y")) {
        self.*[1] = value;
    } else {
        l.raiseErrorStr("invalid field '%s'", .{key.ptr});
    }

    return 0;
}

fn vec2String(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2_SIMD, 1, "Vec2");

    var buf: [64]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "({d}, {d})", .{ self[0], self[1] }) catch |e|
        l.raiseErrorStr("failed to format (%s)", .{ @errorName(e).ptr });

    _ = l.pushString(str);
    return 1;
}

pub fn pushVec3(l: *Lua, v: Vec3_SIMD) void {
    const vec = l.newUserdata(Vec3_SIMD, 0);
    vec.* = v;

    l.setMetatableRegistry("Vec3");
}

pub fn checkVec3(l: *Lua, index: i32) Vec3_SIMD {
    const v = l.checkUserdata(Vec3_SIMD, index, "Vec3");

    return v.*;
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
