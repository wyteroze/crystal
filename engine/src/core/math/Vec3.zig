// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub const Vec3 = extern struct {
    pub const Simd3 = @Vector(3, f32);
    x: f32, y: f32, z: f32,

    pub const zero: Vec3 = .{ .x = 0, .y = 0, .z = 0 };
    pub const one: Vec3 = .{ .x = 1, .y = 1, .z = 1 };

    pub fn new(x: f32, y: f32, z: f32) Vec3 { return .{ .x = x, .y = y, .z = z }; }
    pub fn fromSimd(vec: Simd3) Vec3 { return .{ .x = vec[0], .y = vec[1], .z = vec[2] }; }
    pub fn simd(self: Vec3) Simd3 { return Simd3{ self.x, self.y, self.z }; }
    pub fn arr(self: Vec3) [3]f32 { return .{ self.x, self.y, self.z }; }

    pub fn add(self: Vec3, other: Vec3) Vec3 { return .fromSimd(self.simd() + other.simd()); }
    pub fn sub(self: Vec3, other: Vec3) Vec3 { return .fromSimd(self.simd() - other.simd()); }
    pub fn mul(self: Vec3, other: Vec3) Vec3 { return .fromSimd(self.simd() * other.simd()); }
    pub fn div(self: Vec3, other: Vec3) Vec3 { return .fromSimd(self.simd() / other.simd()); }
    pub fn dot(self: Vec3, other: Vec3) f32 { return @reduce(.Add, self.simd() * other.simd()); }
    pub fn lerp(self: Vec3, other: Vec3, t: f32) Vec3 { return self.add(other.sub(self).scale(t)); }
    pub fn scale(self: Vec3, s: f32) Vec3 { return .fromSimd(self.simd() * @as(Simd3, @splat(s))); }
    pub fn length(self: Vec3) f32 { return @sqrt(self.dot(self)); }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        const a = self.simd();
        const b = other.simd();

        const a_yzx = Simd3{ a[1], a[2], a[0] };
        const a_zxy = Simd3{ a[2], a[0], a[1] };

        const b_yzx = Simd3{ b[1], b[2], b[0] };
        const b_zxy = Simd3{ b[2], b[0], b[1] };

        return fromSimd(a_yzx * b_zxy - a_zxy * b_yzx);
    }
    pub fn normalize(self: Vec3) Vec3 {
        const len = self.length();
        if (len < std.math.floatEps(f32)) return .zero;

        return self.scale(1.0 / len);
    }

    pub fn format(self: Vec3, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "Vec3({d:.2}, {d:.2}, {d:.2})", .{ self.x, self.y, self.z })
            catch "Vec3(?, ?, ?)";
    }

    pub const __lua = .val;
};

pub const registerLua = struct {
    const zlua = @import("zlua");
    const linker = @import("../../scripting/scripting.zig").linker;
    const Vec3Bind = linker.Binding(Vec3, false);

    // wyteroze: Maybe TODO: in the future?
    // Allowing lua to do `foo:Add(fighters)` instead of `foo = foo + fighters` would be swag,
    // but I already tried and it gets really weird (aka doesn't work) when you try to do one of those
    // method shorthands via something like `entity.Components.Rotation:Add(foo)` because `Components.Rotation`
    // is a copy of the Vec3 instead of being the actual source bytes. I tried to fix it but gave up because it
    // was annoying. If we get this sorted out in the future, it would be a sick QOL feature and should be done 
    // for other engine math types like Quat and Mat4. I'm also keeping these functions here so we can reuse them 
    // in case it gets fixed.

    fn addInPlace(l: *zlua.Lua) i32 {
        var self = Vec3Bind.checkPtr(l, 1);
        const other = Vec3Bind.check(l, 2);

        self.* = self.add(other);
        return 0;
    }

    fn subInPlace(l: *zlua.Lua) i32 {
        var self = Vec3Bind.checkPtr(l, 1);
        const other = Vec3Bind.check(l, 2);

        self.* = self.sub(other);
        return 0;
    }

    fn mulInPlace(l: *zlua.Lua) i32 {
        var self = Vec3Bind.checkPtr(l, 1);

        if (l.isNumber(2)) {
            const num = l.toNumber(2) catch |e| linker.util.luaErr(l, e, .{ f64, 2 });
            self.* = Vec3.fromSimd(self.simd() * @as(Vec3.Simd3, @splat(@floatCast(num))));
            return 0;
        }

        self.* = self.mul(Vec3Bind.check(l, 2));
        return 0;
    }

    fn divInPlace(l: *zlua.Lua) i32 {
        var self = Vec3Bind.checkPtr(l, 1);

        if (l.isNumber(2)) {
            const num = l.toNumber(2) catch |e| linker.util.luaErr(l, e, .{ f64, 2 });
            self.* = Vec3.fromSimd(self.simd() / @as(Vec3.Simd3, @splat(@floatCast(num))));
            return 0;
        }

        self.* = self.div(Vec3Bind.check(l, 2));
        return 0;
    }

    pub fn registerLua(l: *zlua.Lua) void {
        linker.value(l, Vec3, .{
            .name = .auto,
            .scope = .{ .module = "core.math" },
            .constructors = &.{ .named("new", Vec3.new) },
            .methods = &.{
                .named("Length", Vec3.length),
                .named("Dot", Vec3.dot),
                .named("Cross", Vec3.cross),
                .named("Scale", Vec3.scale),
                .named("Lerp", Vec3.lerp),
                .named("Normalize", Vec3.normalize)
            },
            .constants = &.{
                .named("zero", Vec3.zero),
                .named("one", Vec3.one)
            },
            .fields = &.{ "x", "y", "z" },
            .ops = .{
                .add = .custom(Vec3.add),
                .sub = .custom(Vec3.sub),
                .mul = .custom(Vec3.mul),
                .div = .custom(Vec3.div),
                .eq = .identity,
                .tostring = .format(Vec3.format)
            }
        });
    }
}.registerLua;