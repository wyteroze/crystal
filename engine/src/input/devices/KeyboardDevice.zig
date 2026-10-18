// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Platform = @import("../../platform/Platform.zig");
const signal = @import("../../core/signal.zig");
const Windowing = @import("../../windowing/Windowing.zig");

pub const KeyEvent = signal.Signal(.{ Platform.desc.Keycode, bool, Windowing.WindowHandle });

const KeyboardDevice = @This();
allocator: std.mem.Allocator,
keys_pressed: std.AutoHashMap(Platform.desc.Keycode, bool),
key_pressed: KeyEvent,
key_released: KeyEvent,
id: usize,

pub fn init(dispatcher: *signal.Dispatcher, allocator: std.mem.Allocator, id: usize) KeyboardDevice {
    return .{ 
        .allocator = allocator, 
        .keys_pressed = .init(allocator),
        .key_pressed = .init(allocator, dispatcher),
        .key_released = .init(allocator, dispatcher),
        .id = id
    };
}

pub fn deinit(self: *KeyboardDevice) void {
    self.keys_pressed.deinit();
    self.key_pressed.deinit();
    self.key_released.deinit();
}

pub fn keyPressed(self: *KeyboardDevice, event: Platform.desc.KeyboardEvent, win: *Windowing.Window) !void {
    self.key_pressed.fire(.{ event.keycode, false, win.getHandle() });
    try self.keys_pressed.put(event.keycode, true);
}

pub fn keyReleased(self: *KeyboardDevice, event: Platform.desc.KeyboardEvent, win: *Windowing.Window) void {
    self.key_released.fire(.{ event.keycode, false, win.getHandle() });
    if (!self.keys_pressed.remove(event.keycode)) 
        std.log.warn("keyReleased() called on KeyboardDevice {d} for a key that isn't pressed", .{ self.id });
}

pub fn isKeyPressed(self: *KeyboardDevice, key: Platform.desc.Keycode) bool {
    return self.keys_pressed.contains(key);
}

pub fn format(
    self: @This(),
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try writer.print("KeyboardDevice {d}", .{ self.id });
}
