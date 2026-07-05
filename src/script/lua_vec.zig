// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const properties = @import("shared/properties.zig");
const types = @import("../types.zig");
const Lua = zlua.Lua;
const Vec2_SIMD = types.Vec2_SIMD;
const Vec3_SIMD = types.Vec3_SIMD;
const Property = properties.Property;

const Vec3Ref = VecRef(Vec3_SIMD);
const Vec2Ref = VecRef(Vec2_SIMD);
fn VecRef(comptime T: type) type {
    return union(enum) {
        pub const Inner = T;
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

fn axisGet(comptime T: type, comptime i: AxisDict) fn (*Lua, *T) i32 {
    return struct {
        fn f(l: *Lua, self: *T) i32 {
            l.pushNumber(self.get()[@intFromEnum(i)]);
            return 1;
        }
    }.f;
}

fn axisSet(comptime T: type, comptime i: AxisDict) fn (*Lua, *T) void {
    return struct {
        fn f(l: *Lua, self: *T) void {
            var v = self.get();
            v[@intFromEnum(i)] = @as(f32, @floatCast(l.toNumber(3) catch 0));

            self.set(v);
        }
    }.f;
}

fn VecOps(comptime T: type) type {
    return struct {
        fn add(a: T, b: T) T { return a + b; }
        fn sub(a: T, b: T) T { return a - b; }
        fn mul(a: T, b: T) T { return a * b; }
        fn div(a: T, b: T) T { return a / b; }
    };
}

fn vecOp(comptime R: type, comptime name: [:0]const u8, comptime op: fn(R.Inner, R.Inner) R.Inner) fn (*Lua) i32 {
    return struct {
        fn c(l: *Lua) i32 {
            const self = l.checkUserdata(R, 1, name);
            const other = l.checkUserdata(R, 2, name);
            self.set(op(self.get(), other.get()));

            l.pushValue(1);
            return 1;
        }
    }.c;
}

fn vecNew(comptime R: type, comptime name: [:0]const u8, comptime n: usize) fn (*Lua) i32 {
    return struct {
        fn f(l: *Lua) i32 {
            var arr: [n]f32 = undefined;
            inline for (0..n) |i| {
                arr[i] = @as(f32, @floatCast(l.toNumber(@intCast(i + 1)) catch 0));
            }

            const vec = l.newUserdata(R, 0);
            vec.* = .{ .value = arr };
            l.setMetatableRegistry(name);

            return 1;
        }
    }.f;
}


fn vecGet(comptime R: type, comptime name: [:0]const u8, comptime props: []const Property(R)) fn (*Lua) i32 {
    return struct {
        fn f(l: *Lua) i32 {
            const self = l.checkUserdata(R, 1, name);
            const key = l.checkString(2);

            if (properties.dispatchIndex(R, props, l, self, key)) |r| return r;

            _ = l.getMetatableRegistry(name);
            l.pushValue(2);
            _ = l.getTableRaw(-2);
            return 1;
        }
    }.f;
}

fn vecSet(comptime R: type, comptime name: [:0]const u8, comptime props: []const Property(R)) fn (*Lua) i32 {
    return struct {
        fn f(l: *Lua) i32 {
            const self = l.checkUserdata(R, 1, name);
            const key = l.checkString(2);

            if (properties.dispatchNewIndex(R, props, l, self, key) != null) return 0;

            l.raiseErrorStr("invalid field '%s'", .{key.ptr});
            return 0;
        }
    }.f;
}

const vec3Lib = [_]zlua.FnReg{
    .{ .name = "new", .func = zlua.wrap(vec3New) }
};

const vec2Lib = [_]zlua.FnReg{
    .{ .name = "new", .func = zlua.wrap(vec2New) }
};

const vec3Methods = [_]zlua.FnReg{
    .{ .name = "Add", .func = zlua.wrap(vecOp(Vec3Ref, "Vec3", VecOps(Vec3_SIMD).add)) },
    .{ .name = "Sub", .func = zlua.wrap(vecOp(Vec3Ref, "Vec3", VecOps(Vec3_SIMD).sub)) },
    .{ .name = "Mul", .func = zlua.wrap(vecOp(Vec3Ref, "Vec3", VecOps(Vec3_SIMD).mul)) },
    .{ .name = "Div", .func = zlua.wrap(vecOp(Vec3Ref, "Vec3", VecOps(Vec3_SIMD).div)) },
    .{ .name = "__add", .func = zlua.wrap(vecOp(Vec3Ref, "Vec3", VecOps(Vec3_SIMD).add)) },
    .{ .name = "__sub", .func = zlua.wrap(vecOp(Vec3Ref, "Vec3", VecOps(Vec3_SIMD).sub)) },
    .{ .name = "__mul", .func = zlua.wrap(vecOp(Vec3Ref, "Vec3", VecOps(Vec3_SIMD).mul)) },
    .{ .name = "__div", .func = zlua.wrap(vecOp(Vec3Ref, "Vec3", VecOps(Vec3_SIMD).div)) },
};

const vec2Methods = [_]zlua.FnReg{
    .{ .name = "Add", .func = zlua.wrap(vecOp(Vec2Ref, "Vec2", VecOps(Vec2_SIMD).add)) },
    .{ .name = "Sub", .func = zlua.wrap(vecOp(Vec2Ref, "Vec2", VecOps(Vec2_SIMD).sub)) },
    .{ .name = "Mul", .func = zlua.wrap(vecOp(Vec2Ref, "Vec2", VecOps(Vec2_SIMD).mul)) },
    .{ .name = "Div", .func = zlua.wrap(vecOp(Vec2Ref, "Vec2", VecOps(Vec2_SIMD).div)) },
    .{ .name = "__add", .func = zlua.wrap(vecOp(Vec2Ref, "Vec2", VecOps(Vec2_SIMD).add)) },
    .{ .name = "__sub", .func = zlua.wrap(vecOp(Vec2Ref, "Vec2", VecOps(Vec2_SIMD).sub)) },
    .{ .name = "__mul", .func = zlua.wrap(vecOp(Vec2Ref, "Vec2", VecOps(Vec2_SIMD).mul)) },
    .{ .name = "__div", .func = zlua.wrap(vecOp(Vec2Ref, "Vec2", VecOps(Vec2_SIMD).div)) },
};

const AxisDict = enum(usize) { x, y, z };
const vec3_props = [_]Property(Vec3Ref){
    .{ .name = "X", .get = axisGet(Vec3Ref, .x), .set = axisSet(Vec3Ref, .x) },
    .{ .name = "Y", .get = axisGet(Vec3Ref, .y), .set = axisSet(Vec3Ref, .y) },
    .{ .name = "Z", .get = axisGet(Vec3Ref, .z), .set = axisSet(Vec3Ref, .z) }
};
const vec2_props = [_]Property(Vec2Ref){
    .{ .name = "X", .get = axisGet(Vec2Ref, .x), .set = axisSet(Vec2Ref, .x) },
    .{ .name = "Y", .get = axisGet(Vec2Ref, .y), .set = axisSet(Vec2Ref, .y) },
};

const vec3New = vecNew(Vec3Ref, "Vec3", 3);
const vec2New = vecNew(Vec2Ref, "Vec2", 2);
const vec3Get = vecGet(Vec3Ref, "Vec3", &vec3_props);
const vec2Get = vecGet(Vec2Ref, "Vec2", &vec2_props);
const vec3Set = vecGet(Vec3Ref, "Vec3", &vec3_props);
const vec2Set = vecGet(Vec2Ref, "Vec2", &vec2_props);

// Vec3
fn vec3String(l: *Lua) i32 {
    const self = l.checkUserdata(Vec3Ref, 1, "Vec3");
    const vec = self.get();

    var buf: [96]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "({d}, {d}, {d})", .{ vec[0], vec[1], vec[2] }) catch |e|
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

// Vec2
fn vec2String(l: *Lua) i32 {
    const self = l.checkUserdata(Vec2Ref, 1, "Vec2");
    const vec = self.get();

    var buf: [64]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "({d}, {d})", .{ vec[0], vec[1] }) catch |e|
        l.raiseErrorStr("failed to format (%s)", .{ @errorName(e).ptr });

    _ = l.pushString(str);
    return 1;
}

pub fn pushVec2(l: *Lua, v: Vec2_SIMD) void {
    const vec = l.newUserdata(Vec2_SIMD, 0);
    vec.* = v;

    l.setMetatableRegistry("Vec2");
}

pub fn checkVec2(l: *Lua, index: i32) Vec2_SIMD {
    const v = l.checkUserdata(Vec2Ref, index, "Vec2");

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
