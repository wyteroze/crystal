// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub const Vec2 = extern struct {
    pub const Simd2 = @Vector(2, f32);
    x: f32, y: f32,

    pub const zero: Vec2 = .{ .x = 0, .y = 0 };
    pub const one: Vec2 = .{ .x = 1, .y = 1 };

    pub fn new(x: f32, y: f32) Vec2 { return .{ .x = x, .y = y }; }
    pub fn fromSimd(vec: Simd2) Vec2 { return .{ .x = vec[0], .y = vec[1] }; }
    pub fn simd(self: Vec2) Simd2 { return Simd2{ self.x, self.y }; }
    pub fn arr(self: Vec2) [2]f32 { return .{ self.x, self.y }; }

    pub fn add(self: Vec2, other: Vec2) Vec2 { return .fromSimd(self.simd() + other.simd()); }
    pub fn sub(self: Vec2, other: Vec2) Vec2 { return .fromSimd(self.simd() - other.simd()); }
    pub fn mul(self: Vec2, other: Vec2) Vec2 { return .fromSimd(self.simd() * other.simd()); }
    pub fn div(self: Vec2, other: Vec2) Vec2 { return .fromSimd(self.simd() / other.simd()); }
    pub fn dot(self: Vec2, other: Vec2) f32 { return @reduce(.Add, self.simd() * other.simd()); }
    pub fn lerp(self: Vec2, other: Vec2, t: f32) Vec2 { return self.add(other.sub(self).scale(t)); }
    pub fn scale(self: Vec2, s: f32) Vec2 { return .fromSimd(self.simd() * @as(Simd2, @splat(s))); }
    pub fn length(self: Vec2) f32 { return @sqrt(self.dot(self)); }

    pub fn toRadians(self: Vec2) Vec2 { return .fromSimd(self.simd() * @as(Simd2, @splat(std.math.pi / 180.0))); }
    pub fn toDegrees(self: Vec2) Vec2 { return .fromSimd(self.simd() * @as(Simd2, @splat(180.0 / std.math.pi))); }

    pub fn normalize(self: Vec2) Vec2 {
        const len = self.length();
        if (len < std.math.floatEps(f32)) return .zero;

        return self.scale(1.0 / len);
    }

    pub fn format(self: Vec2, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "Vec2({d:.2}, {d:.2})", .{ self.x, self.y })
            catch "Vec2(?, ?)";
    }

    pub const __lua = .val;
};

pub const registerLua = struct {
    const zlua = @import("zlua");
    const linker = @import("../../scripting/scripting.zig").linker;
    const Vec2Bind = linker.Binding(Vec2, false);

    // wyteroze: Maybe TODO: in the future?
    // Allowing lua to do `foo:Add(fighters)` instead of `foo = foo + fighters` would be swag,
    // but I already tried and it gets really weird (aka doesn't work) when you try to do one of those
    // method shorthands via something like `entity.Components.Rotation:Add(foo)` because `Components.Rotation`
    // is a copy of the Vec2 instead of being the actual source bytes. I tried to fix it but gave up because it
    // was annoying. If we get this sorted out in the future, it would be a sick QOL feature and should be done 
    // for other engine math types like Quat and Mat4. I'm also keeping these functions here so we can reuse them 
    // in case it gets fixed.

    fn addInPlace(l: *zlua.Lua) i32 {
        var self = Vec2Bind.checkPtr(l, 1);
        const other = Vec2Bind.check(l, 2);

        self.* = self.add(other);
        return 0;
    }

    fn subInPlace(l: *zlua.Lua) i32 {
        var self = Vec2Bind.checkPtr(l, 1);
        const other = Vec2Bind.check(l, 2);

        self.* = self.sub(other);
        return 0;
    }

    fn mulInPlace(l: *zlua.Lua) i32 {
        var self = Vec2Bind.checkPtr(l, 1);

        if (l.isNumber(2)) {
            const num = l.toNumber(2) catch |e| linker.util.luaErr(l, e, .{ f64, 2 });
            self.* = Vec2.fromSimd(self.simd() * @as(Vec2.Simd2, @splat(@floatCast(num))));
            return 0;
        }

        self.* = self.mul(Vec2Bind.check(l, 2));
        return 0;
    }

    fn divInPlace(l: *zlua.Lua) i32 {
        var self = Vec2Bind.checkPtr(l, 1);

        if (l.isNumber(2)) {
            const num = l.toNumber(2) catch |e| linker.util.luaErr(l, e, .{ f64, 2 });
            self.* = Vec2.fromSimd(self.simd() / @as(Vec2.Simd2, @splat(@floatCast(num))));
            return 0;
        }

        self.* = self.div(Vec2Bind.check(l, 2));
        return 0;
    }

    pub fn registerLua(l: *zlua.Lua) void {
        linker.value(l, Vec2, .{
            .name = .auto,
            .scope = .{ .module = "core.math" },
            .constructors = &.{ .named("new", Vec2.new) },
            .methods = &.{
                .named("Length", Vec2.length),
                .named("Dot", Vec2.dot),
                .named("Scale", Vec2.scale),
                .named("Lerp", Vec2.lerp),
                .named("Normalize", Vec2.normalize)
            },
            .constants = &.{
                .named("zero", Vec2.zero),
                .named("one", Vec2.one)
            },
            .fields = &.{ "x", "y" },
            .ops = .{
                .add = .custom(Vec2.add),
                .sub = .custom(Vec2.sub),
                .mul = .custom(Vec2.mul),
                .div = .custom(Vec2.div),
                .eq = .identity,
                .tostring = .format(Vec2.format)
            }
        });
    }
}.registerLua;