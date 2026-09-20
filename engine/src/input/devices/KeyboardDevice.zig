// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Platform = @import("../../platform/Platform.zig");
const signal = @import("../../core/signal.zig");

const KeyboardDevice = @This();
allocator: std.mem.Allocator,
keys_pressed: std.AutoHashMap(Platform.desc.Keycode, bool),
key_pressed: signal.Signal(.{ Platform.desc.Keycode }),
key_released: signal.Signal(.{ Platform.desc.Keycode }),
id: usize,

pub fn init(allocator: std.mem.Allocator, id: usize) KeyboardDevice {
    return .{ 
        .allocator = allocator, 
        .keys_pressed = .init(allocator),
        .key_pressed = .init(allocator),
        .key_released = .init(allocator),
        .id = id
    };
}

pub fn deinit(self: *KeyboardDevice) void {
    if (self.keys_pressed.count() > 0) {
        var iter = self.keys_pressed.keyIterator();
        while (iter.next()) |kp| std.log.warn("{f}", .{ kp.* });
        std.log.warn("The keys above are currently in KeyboardDevice {d}'s pressed keys list even though it's being deinitialized. Were any events dropped during its lifetime?", .{ self.id });
    }

    self.keys_pressed.deinit();
    self.key_pressed.deinit();
    self.key_released.deinit();
}

pub fn keyPressed(self: *KeyboardDevice, event: Platform.desc.KeyboardEvent) void {
    self.key_pressed.fire(.{ event.keycode });
    self.keys_pressed.put(event.keycode, true) catch |e| @panic(@errorName(e));
}

pub fn keyReleased(self: *KeyboardDevice, event: Platform.desc.KeyboardEvent) void {
    self.key_released.fire(.{ event.keycode });
    if (!self.keys_pressed.remove(event.keycode)) std.log.warn("keyReleased() called on KeyboardDevice {d} for a key that isn't pressed", .{ self.id });
}

pub fn isKeyDown(self: *KeyboardDevice, key: Platform.desc.Keycode) bool {
    return self.keys_pressed.contains(key);
}

pub const __lua = .ref;
pub const registerLua = struct {
    const linker = @import("../../scripting/linker/linker.zig");
    const zlua = @import("zlua");
    const KeyboardDeviceBind = linker.Binding(KeyboardDevice, true);

    fn keyboardDeviceGet(l: *zlua.Lua) i32 {
        const self = KeyboardDeviceBind.check(l, 1);
        const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });
        
        if (std.mem.eql(u8, key, "KeyPressed")) {
            linker.util.pushVal(l, *signal.Signal(.{ Platform.desc.Keycode }), &self.key_pressed);
            return 1;
        } else if (std.mem.eql(u8, key, "KeyReleased")) {
            linker.util.pushVal(l, *signal.Signal(.{ Platform.desc.Keycode }), &self.key_released);
            return 1;
        }  else if (std.mem.eql(u8, key, "Id")) {
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

    fn keyboardDeviceSet(l: *zlua.Lua) i32 {
        l.raiseErrorStr("KeyboardDevice is read-only", .{});
    }

    pub fn registerLua(l: *zlua.Lua) void {
        linker.signal(l, signal.Signal(.{ Platform.desc.Keycode }));
        
        linker.reference(l, KeyboardDevice, .{
            .scope = .{ .module = "input.devices.KeyboardDevice" },
            .properties = .luaCustom(keyboardDeviceGet, keyboardDeviceSet),
            .methods = &.{
                .named("IsKeyDown", KeyboardDevice.isKeyDown)
            }
        });
    }
}.registerLua;