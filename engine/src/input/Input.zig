// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const core = @import("../core/core.zig");
const devices = @import("devices/devices.zig");
const signal = @import("../core/signal.zig");
const Platform = @import("../platform/Platform.zig");
const Windowing = @import("../windowing/Windowing.zig");
const Ui = @import("../ui/Ui.zig");

const max_usize = std.math.maxInt(usize);

pub const KeyboardConnectionEvent = signal.Signal(.{ KeyboardHandle });
pub const KeyboardEvent = signal.Signal(.{ KeyboardHandle, bool, Windowing.WindowHandle });
pub const MouseConnectionEvent = signal.Signal(.{ MouseHandle });
pub const MouseEvent = signal.Signal(.{ MouseHandle, bool, Windowing.WindowHandle });
pub const GamepadConnectionEvent = signal.Signal(.{ GamepadHandle });
pub const GamepadEvent = signal.Signal(.{ GamepadHandle, bool, Windowing.WindowHandle });

pub const KeyboardHandle = devices.DeviceHandle(devices.KeyboardDevice, "keyboards");
pub const MouseHandle = devices.DeviceHandle(devices.MouseDevice, "mice");
pub const GamepadHandle = devices.DeviceHandle(devices.GamepadDevice, "gamepads");
pub const TouchHandle = devices.DeviceHandle(devices.TouchDevice, "touch_devices");

const Input = @This();
allocator: std.mem.Allocator,
platform: *Platform,
ui: *Ui,
windowing: *Windowing,

platform_event_con: signal.Connection,

dispatcher: signal.Dispatcher,
// Keyboard events
keyboard_connected: KeyboardConnectionEvent,
keyboard_disconnected: KeyboardConnectionEvent,
// Mouse events
mouse_connected: MouseConnectionEvent,
mouse_disconnected: MouseConnectionEvent,
// Gamepad events
gamepad_connected: GamepadConnectionEvent,
gamepad_disconected: GamepadConnectionEvent,

// Unidevices (no matter what ID an event comes from,
// it goes to the unidevice in addition to the device that the event is for)
unikeyboard: *devices.KeyboardDevice,
unimouse: *devices.MouseDevice,
unigamepad: *devices.GamepadDevice,
unitouchdevice: *devices.TouchDevice,

// Connected devices
keyboards: std.AutoHashMap(usize, *devices.KeyboardDevice),
mice: std.AutoHashMap(usize, *devices.MouseDevice),
gamepads: std.AutoHashMap(usize, *devices.GamepadDevice),
touch_devices: std.AutoHashMap(usize, *devices.TouchDevice),

pub fn init(self: *Input, allocator: std.mem.Allocator, platform: *Platform, ui: *Ui, windowing: *Windowing,) !void {
    var keyboards: std.AutoHashMap(usize, *devices.KeyboardDevice) = .init(allocator);
    var mice: std.AutoHashMap(usize, *devices.MouseDevice) = .init(allocator);
    var gamepads: std.AutoHashMap(usize, *devices.GamepadDevice) = .init(allocator);
    var touch_devices: std.AutoHashMap(usize, *devices.TouchDevice) = .init(allocator);

    self.*.dispatcher = .init(allocator);

    // Unidevices
    const unikeyboard = try allocator.create(devices.KeyboardDevice);
    unikeyboard.* = .init(&self.dispatcher, allocator, max_usize);
    try keyboards.put(max_usize, unikeyboard);

    const unimouse = try allocator.create(devices.MouseDevice);
    unimouse.* = .init(&self.dispatcher, allocator, max_usize);
    try mice.put(max_usize, unimouse);

    const unigamepad = try allocator.create(devices.GamepadDevice);
    unigamepad.* = .init(&self.dispatcher, allocator);
    try gamepads.put(max_usize, unigamepad);

    const unitouchdevice = try allocator.create(devices.TouchDevice);
    unitouchdevice.* = .init(&self.dispatcher, allocator);
    try touch_devices.put(max_usize, unitouchdevice);

    const platform_event_con = try platform.platform_event.connect(struct {
        fn c(slf: *Input, evt: Platform.desc.PlatformEvent) void {
            slf.onPlatformEvent(evt) catch |e| std.debug.panic("Input.onPlatformEvent panic: {any}", .{ e });
        }
    }.c, self);

    self.* = .{
        .allocator = allocator,
        .platform = platform,
        .ui = ui,
        .windowing = windowing,
        .platform_event_con = platform_event_con,
        .dispatcher = self.dispatcher,
        .keyboards = keyboards,
        .mice = mice,
        .gamepads = gamepads,
        .touch_devices = touch_devices,
        .keyboard_connected = .init(allocator, &self.dispatcher),
        .keyboard_disconnected = .init(allocator, &self.dispatcher),
        .mouse_connected = .init(allocator, &self.dispatcher),
        .mouse_disconnected = .init(allocator, &self.dispatcher),
        .gamepad_connected = .init(allocator, &self.dispatcher),
        .gamepad_disconected = .init(allocator, &self.dispatcher),
        .unikeyboard = unikeyboard,
        .unimouse = unimouse,
        .unigamepad = unigamepad,
        .unitouchdevice = unitouchdevice,
    };
}

pub fn deinit(self: *Input) void {
    var kb_iter = self.keyboards.valueIterator();
    var ms_iter = self.mice.valueIterator();
    var gp_iter = self.gamepads.valueIterator();
    var td_iter = self.touch_devices.valueIterator();

    while (kb_iter.next()) |kb| { kb.*.deinit(); self.allocator.destroy(kb.*); }
    while (ms_iter.next()) |ms| { ms.*.deinit(); self.allocator.destroy(ms.*); }
    while (gp_iter.next()) |gp| { gp.*.deinit(); self.allocator.destroy(gp.*); }
    while (td_iter.next()) |td| { td.*.deinit(); self.allocator.destroy(td.*); }
    
    self.keyboards.deinit();
    self.mice.deinit();
    self.gamepads.deinit();
    self.touch_devices.deinit();
    self.keyboard_connected.deinit();
    self.keyboard_disconnected.deinit();
    self.mouse_connected.deinit();
    self.mouse_disconnected.deinit();
    self.gamepad_connected.deinit();
    self.gamepad_disconected.deinit();
    self.dispatcher.deinit();
}

fn onPlatformEvent(self: *Input, event: Platform.desc.PlatformEvent) !void {
    switch (event) {
        .keyboard_connected => |e| { 
            const kb = try self.allocator.create(devices.KeyboardDevice);
            errdefer self.allocator.destroy(kb);

            kb.* = .init(&self.dispatcher, self.allocator, e.id);
            try self.keyboards.put(@intCast(e.id), kb);

            self.keyboard_connected.fire(.{ .{ .input = self, .id = e.id } });
        },
        .keyboard_disconnected => |e| { 
            const h: KeyboardHandle = .{ .input = self, .id = e.id };
            if (!h.isAlive()) { std.log.err("Attempt to disconnect kb id {d}, but it doesn't exist/isn't registered", .{ e.id }); return; }
            
            self.keyboard_disconnected.fire(.{ h });

            const kv = self.keyboards.fetchRemove(@intCast(e.id)).?;
            kv.value.deinit();
            self.allocator.destroy(kv.value);
        },
        .keyboard_key_down => |e| { 
            const win = self.windowing.getWindowFromId(e.window_id) orelse return;
            try self.unikeyboard.keyPressed(e, win); 
            try (self.getKeyboard(e.keyboard_id) orelse return).keyPressed(e, win); 
        },
        .keyboard_key_up => |e| { 
            const win = self.windowing.getWindowFromId(e.window_id) orelse return;
            self.unikeyboard.keyReleased(e, win); 
            (self.getKeyboard(e.keyboard_id) orelse return).keyReleased(e, win); 
        },
        .mouse_connected => |e| {
            const ms = try self.allocator.create(devices.MouseDevice);
            errdefer self.allocator.destroy(ms);

            ms.* = .init(&self.dispatcher, self.allocator, e.id);
            try self.mice.put(@intCast(e.id), ms);

            self.mouse_connected.fire(.{ .{ .input = self, .id = e.id } });
        },
        .mouse_disconnected => |e| {
            const h: MouseHandle = .{ .input = self, .id = e.id };
            if (!h.isAlive()) { std.log.err("Attempt to disconnect mouse id {d}, but it doesn't exist/isn't registered", .{ e.id }); return; }
            
            self.mouse_disconnected.fire(.{ h });

            const kv = self.mice.fetchRemove(@intCast(e.id)).?;
            kv.value.deinit();
            self.allocator.destroy(kv.value);
        },
        .mouse_button_down => |e| {
            const win = self.windowing.getWindowFromId(e.window_id) orelse return;
            var ms = self.getMouse(e.mouse_id) orelse return;

            const consumed = self.ui.pointerPressed(ms.getPosition());
            try self.unimouse.buttonDown(e, consumed, win); 
            try ms.buttonDown(e, consumed, win);
        },
        .mouse_button_up => |e| {
            const win = self.windowing.getWindowFromId(e.window_id) orelse return;
            var ms = self.getMouse(e.mouse_id) orelse return;

            const consumed = self.ui.pointerReleased(ms.getPosition());
            self.unimouse.buttonUp(e, consumed, win); 
            ms.buttonUp(e, consumed, win);
        },
        .mouse_scrolled => |e| {
            const win = self.windowing.getWindowFromId(e.window_id) orelse return;
            self.unimouse.scrolled(e, win); 
            (self.getMouse(e.mouse_id) orelse return).scrolled(e, win);
        },
        .mouse_moved => |e| {
            const win = self.windowing.getWindowFromId(e.window_id) orelse return;
            var ms = self.getMouse(e.mouse_id) orelse return;
            const consumed = self.ui.pointerMoved(ms.getPosition());

            self.unimouse.moved(e, consumed, win); 
            ms.moved(e, consumed, win);
        },
        else => {}
    }
}

// Called at the start of every frame
pub fn tick(self: *Input) void {
    var ms_iter = self.mice.valueIterator();
    while (ms_iter.next()) |ms| ms.*.resetDeltas();
    self.dispatcher.flush();
}

pub fn getKeyboard(self: *Input, id: usize) ?*devices.KeyboardDevice {
    return self.keyboards.get(id);
}

pub fn getMouse(self: *Input, id: usize) ?*devices.MouseDevice {
    return self.mice.get(id);
}

pub fn getGamepad(self: *Input, id: usize) ?*devices.GamepadDevice {
    return self.gamepads.get(id);
}

pub fn getTouchDevice(self: *Input, id: usize) ?*devices.TouchDevice {
    return self.touch_devices.get(id);
}

pub fn setCursorLocked(self: *Input, mode: bool) void {
    self.platform.setCursorLocked(mode);
}

pub fn getCursorLocked(self: *Input) bool {
    return self.platform.getCursorLocked();
}

pub fn setCursorVisible(self: *Input, mode: bool) void {
    self.platform.setCursorVisible(mode);
}

pub fn getCursorVisible(self: *Input) bool {
    return self.platform.getCursorVisible();
}

const bind = @import("../scripting/bind/bind.zig");

pub const api = bind.module("input", .{
    .kind = .{ .singleton = Input },
    .members = &.{
        bind.func("IsCursorLocked", getCursorLocked),
        bind.func("SetCursorLocked", setCursorLocked),
        bind.func("IsCursorVisible", getCursorVisible),
        bind.func("SetCursorVisible", setCursorVisible),
        bind.func("GetKeyboard", struct {
            fn c(self: *Input, id: usize) ?KeyboardHandle {
                return if (self.keyboards.contains(id)) .{ .input = self, .id = id } else null;
            }
        }.c),
        bind.func("GetMouse", struct {
            fn c(self: *Input, id: usize) ?MouseHandle {
                return if (self.mice.contains(id)) .{ .input = self, .id = id } else null;
            }
        }.c),
        bind.readonly("Keyboards", struct {
            fn c(self: *Input) KeyboardHandle {
                return .{ .input = self, .id = self.unikeyboard.id };
            }
        }.c),
        bind.readonly("Mice", struct {
            fn c(self: *Input) MouseHandle {
                return .{ .input = self, .id = self.unimouse.id };
            }
        }.c),

        bind.handle(KeyboardHandle, .{
            .name = "Keyboard",
            .alive = bind.func("isAlive", KeyboardHandle.isAlive),
            .methods = &.{
                bind.func("IsKeyPressed", struct {
                    fn c(self: KeyboardHandle, key: Platform.desc.Keycode) !bool {
                        return (try self.require()).isKeyPressed(key);
                    }
                }.c)
            },
            .props = &.{
                bind.readonly("Id", struct {
                    fn c(self: KeyboardHandle) usize { return self.id; }
                }.c),
            },
            .signals = &.{
                bind.signal("KeyPressed", struct {
                    fn c(self: KeyboardHandle) !*devices.KeyboardDevice.KeyEvent {
                        return &(try self.require()).key_pressed;
                    }
                }.c),
                bind.signal("KeyReleased", struct {
                    fn c(self: KeyboardHandle) !*devices.KeyboardDevice.KeyEvent {
                        return &(try self.require()).key_released;
                    }
                }.c),
            },
            .ops = .{ .eq = .{ .member = bind.func("eq", KeyboardHandle.eql) }, .tostring = .auto },
        }),
        bind.handle(MouseHandle, .{
            .name = "Mouse",
            .alive = bind.func("isAlive", MouseHandle.isAlive),
            .methods = &.{
                bind.func("IsButtonDown", struct {
                    fn c(self: MouseHandle, button: Platform.desc.MouseButton) !bool {
                        return (try self.require()).isButtonDown(button);
                    }
                }.c),
                bind.func("GetMoveDelta", struct {
                    fn c(self: MouseHandle) !core.math.Vec2 {
                        return (try self.require()).getMoveDelta();
                    }
                }.c),
            },
            .props = &.{
                bind.readonly("Id", struct {
                    fn c(self: MouseHandle) usize { return self.id; }
                }.c),
            },
            .signals = &.{
                bind.signal("ButtonPressed", struct {
                    fn c(self: MouseHandle) !*devices.MouseDevice.ButtonEvent {
                        return &(try self.require()).button_pressed;
                    }
                }.c),
                bind.signal("ButtonReleased", struct {
                    fn c(self: MouseHandle) !*devices.MouseDevice.ButtonEvent {
                        return &(try self.require()).button_released;
                    }
                }.c),
                bind.signal("Scrolled", struct {
                    fn c(self: MouseHandle) !*devices.MouseDevice.ScrollEvent {
                        return &(try self.require()).scrolled_evt;
                    }
                }.c),
            },
            .ops = .{ .eq = .{ .member = bind.func("eq", MouseHandle.eql) }, .tostring = .auto },
        })
    }
});
