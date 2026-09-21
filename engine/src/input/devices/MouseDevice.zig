// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Platform = @import("../../platform/Platform.zig");
const core = @import("../../core/core.zig");
const signal = core.signal;
const math = core.math;

const MouseDevice = @This();
allocator: std.mem.Allocator,
buttons_pressed: std.AutoHashMap(Platform.desc.MouseButton, bool),
button_pressed: signal.Signal(.{ Platform.desc.MouseButton }),
button_released: signal.Signal(.{ Platform.desc.MouseButton }),
moved_evt: signal.Signal(.{ math.Vec2, math.Vec2 }),
scrolled_evt: signal.Signal(.{ math.Vec2 }),
id: usize,
frame_pos: math.Vec2 = .zero,
frame_delta: math.Vec2 = .zero,
scroll_delta: math.Vec2 = .zero,

pub fn init(allocator: std.mem.Allocator, id: usize) MouseDevice {
    return .{ 
        .allocator = allocator,
        .buttons_pressed = .init(allocator),
        .button_pressed = .init(allocator),
        .button_released = .init(allocator),
        .moved_evt = .init(allocator),
        .scrolled_evt = .init(allocator),
        .id = id
    };
}

pub fn deinit(self: *MouseDevice) void {
    self.buttons_pressed.deinit();
    self.button_pressed.deinit();
    self.button_released.deinit();
    self.moved_evt.deinit();
    self.scrolled_evt.deinit();
}

pub fn buttonDown(self: *MouseDevice, event: Platform.desc.MouseButtonEvent) !void {
    self.button_pressed.fire(.{ event.button });
    try self.buttons_pressed.put(event.button, true);
} 

pub fn buttonUp(self: *MouseDevice, event: Platform.desc.MouseButtonEvent) void {
    self.button_released.fire(.{ event.button });
    if (!self.buttons_pressed.remove(event.button)) 
        std.log.warn("buttonUp() called on MouseDevice {d} for a button that isn't pressed", .{ self.id });
}

pub fn isButtonDown(self: *MouseDevice, key: Platform.desc.MouseButton) bool {
    return self.buttons_pressed.contains(key);
}

pub fn getDelta(self: *MouseDevice) math.Vec2 {
    return self.frame_delta;
}

pub fn getPosition(self: *MouseDevice) math.Vec2 {
    return self.frame_pos;
}

pub fn getScrollDelta(self: *MouseDevice) math.Vec2 {
    return self.scroll_delta;
}

pub fn resetDeltas(self: *MouseDevice) void {
    self.frame_delta = .zero;
    self.scroll_delta = .zero;
}

pub fn scrolled(self: *MouseDevice, event: Platform.desc.MouseScrollEvent) void {
    const delta = math.Vec2.new(event.delta[0], event.delta[1]);

    self.scroll_delta = delta;
    self.scrolled_evt.fire(.{ delta });
}

pub fn moved(self: *MouseDevice, event: Platform.desc.MouseMoveEvent) void {
    const delta = math.Vec2.new(event.delta[0], event.delta[1]);
    const pos = math.Vec2.new(event.position[0], event.position[1]);

    self.frame_delta = delta;
    self.frame_pos = pos;
    self.moved_evt.fire(.{ delta, pos });
}

pub const __lua = .ref;
pub const registerLua = struct {
    const linker = @import("../../scripting/linker/linker.zig");
    const zlua = @import("zlua");
    const MouseDeviceBind = linker.Binding(MouseDevice, true);

    fn pushSignal(l: *zlua.Lua, sig: anytype) void {
        linker.util.pushVal(l, @TypeOf(sig), sig);
    }

    fn mouseDeviceGet(l: *zlua.Lua) i32 {
        const self = MouseDeviceBind.check(l, 1);
        const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });
        
        if (std.mem.eql(u8, key, "ButtonPressed")) {
            pushSignal(l, &self.button_pressed);
            return 1;
        } else if (std.mem.eql(u8, key, "ButtonReleased")) {
            pushSignal(l, &self.button_released);
            return 1;
        } else if (std.mem.eql(u8, key, "Scrolled")) {
            pushSignal(l, &self.scrolled_evt);
            return 1;
        } else if (std.mem.eql(u8, key, "Moved")) {
            pushSignal(l, &self.moved_evt);
            return 1;
        } else if (std.mem.eql(u8, key, "Id")) {
            l.pushInteger(@intCast(self.id));
            return 1;
        } else {
            // fallback to exising methods
            l.getMetatable(1) catch { l.pushNil(); return 1; };
            _ = l.getField(-1, "__methods");
            l.pushValue(2);
            _ = l.getTable(-2);

            return 1;
        }
    }

    fn mouseDeviceSet(l: *zlua.Lua) i32 {
        l.raiseErrorStr("MouseDevice is read-only", .{});
    }

    pub fn registerLua(l: *zlua.Lua) void {
        linker.signal(l, signal.Signal(.{ Platform.desc.MouseButton }));
        linker.signal(l, signal.Signal(.{ math.Vec2 }));
        linker.signal(l, signal.Signal(.{ math.Vec2, math.Vec2 }));
        
        linker.reference(l, MouseDevice, .{
            .scope = .{ .module = "input.devices.MouseDevice" },
            .properties = .luaCustom(mouseDeviceGet, mouseDeviceSet),
            .methods = &.{
                .named("IsButtonDown", MouseDevice.isButtonDown),
                .named("GetDelta", MouseDevice.getDelta),
                .named("GetPosition", MouseDevice.getPosition),
                .named("GetScrollDelta", MouseDevice.getScrollDelta)
            }
        });
    }
}.registerLua;