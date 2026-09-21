// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const devices = @import("devices/devices.zig");
const signal = @import("../core/signal.zig");
const Platform = @import("../platform/Platform.zig");

const max_usize = std.math.maxInt(usize);

const Input = @This();
allocator: std.mem.Allocator,
platform: *Platform,

// this sucks.. TODO: make this not suck
platform_event_con: signal.SignalConnection(signal.Signal(.{ Platform.desc.PlatformEvent })),

// Keyboard events
keyboard_connected: signal.Signal(.{ *devices.KeyboardDevice }),
keyboard_disconnected: signal.Signal(.{ *devices.KeyboardDevice }),
// Mouse events
mouse_connected: signal.Signal(.{ *devices.MouseDevice }),
mouse_disconnected: signal.Signal(.{ *devices.MouseDevice }),
// Gamepad events
gamepad_connected: signal.Signal(.{ *devices.GamepadDevice }),
gamepad_disconected: signal.Signal(.{ *devices.GamepadDevice }),

// Unidevices (no matter what ID an event comes from,
// it goes to the unidevice in addition to the device that the event is for)
unikeyboard: *devices.KeyboardDevice,
unimouse: *devices.MouseDevice,
unigamepad: *devices.GamepadDevice,
unitouchdevice: *devices.TouchDevice,

// Connected devices
keyboards: std.AutoHashMap(usize, devices.KeyboardDevice),
mice: std.AutoHashMap(usize, devices.MouseDevice),
gamepads: std.AutoHashMap(usize, devices.GamepadDevice),
touch_devices: std.AutoHashMap(usize, devices.TouchDevice),

pub fn init(self: *Input, allocator: std.mem.Allocator, platform: *Platform) !void {
    var keyboards: std.AutoHashMap(usize, devices.KeyboardDevice) = .init(allocator);
    var mice: std.AutoHashMap(usize, devices.MouseDevice) = .init(allocator);
    var gamepads: std.AutoHashMap(usize, devices.GamepadDevice) = .init(allocator);
    var touch_devices: std.AutoHashMap(usize, devices.TouchDevice) = .init(allocator);

    // Unidevices
    try keyboards.put(max_usize, .init(allocator, max_usize));
    try mice.put(max_usize, .init(allocator, max_usize));
    try gamepads.put(max_usize, .init(allocator));
    try touch_devices.put(max_usize, .init(allocator));

    const platform_event_con = try platform.platform_event.connect(struct {
        fn c(slf: *Input, evt: Platform.desc.PlatformEvent) void {
            slf.onPlatformEvent(evt) catch |e| std.debug.panic("input.Input.onPlatformEvent panic: {any}", .{ e });
        }
    }.c, self);

    self.* = .{
        .allocator = allocator,
        .platform = platform,
        .platform_event_con = platform_event_con,
        .keyboards = keyboards,
        .mice = mice,
        .gamepads = gamepads,
        .touch_devices = touch_devices,
        .keyboard_connected = .init(allocator),
        .keyboard_disconnected = .init(allocator),
        .mouse_connected = .init(allocator),
        .mouse_disconnected = .init(allocator),
        .gamepad_connected = .init(allocator),
        .gamepad_disconected = .init(allocator),
        .unikeyboard = keyboards.getPtr(max_usize).?,
        .unimouse = mice.getPtr(max_usize).?,
        .unigamepad = gamepads.getPtr(max_usize).?,
        .unitouchdevice = touch_devices.getPtr(max_usize).?,
    };
}

pub fn deinit(self: *Input) void {
    var kb_iter = self.keyboards.valueIterator();
    var ms_iter = self.mice.valueIterator();
    var gp_iter = self.gamepads.valueIterator();
    var td_iter = self.touch_devices.valueIterator();

    while (kb_iter.next()) |kb| kb.deinit();
    while (ms_iter.next()) |ms| ms.deinit();
    while (gp_iter.next()) |gp| gp.deinit();
    while (td_iter.next()) |td| td.deinit();
    
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
}

fn onPlatformEvent(self: *Input, event: Platform.desc.PlatformEvent) !void {
    switch (event) {
        .keyboard_connected => |e| { 
            try self.keyboards.put(@intCast(e.id), .init(self.allocator, e.id));
            self.keyboard_connected.fire(.{ self.getKeyboard(e.id).? });
        },
        .keyboard_disconnected => |e| { 
            var kb = self.keyboards.fetchRemove(@intCast(e.id))
                orelse { std.log.err("Attempt to disconnect kb id {d}, but it doesn't exist/isn't registered", .{ e.id }); return; };
            
            self.keyboard_disconnected.fire(.{ &kb.value });
        },
        .keyboard_key_down => |e| { 
            try self.unikeyboard.keyPressed(e); 
            try (self.getKeyboard(e.keyboard_id) orelse return).keyPressed(e); 
        },
        .keyboard_key_up => |e| { 
            self.unikeyboard.keyReleased(e); 
            (self.getKeyboard(e.keyboard_id) orelse return).keyReleased(e); 
        },
        .mouse_connected => |e| {
            try self.mice.put(@intCast(e.id), .init(self.allocator, e.id));
            self.mouse_connected.fire(.{ self.getMouse(e.id).? });
        },
        .mouse_disconnected => |e| {
            var ms = self.mice.fetchRemove(@intCast(e.id))
                orelse { std.log.err("Attempt to disconnect mouse id {d}, but it doesn't exist/isn't registered", .{ e.id }); return; };
            self.mouse_disconnected.fire(.{ &ms.value });
        },
        .mouse_button_down => |e| {
            try self.unimouse.buttonDown(e); 
            try (self.getMouse(e.mouse_id) orelse return).buttonDown(e);
        },
        .mouse_button_up => |e| {
            self.unimouse.buttonUp(e); 
            (self.getMouse(e.mouse_id) orelse return).buttonUp(e);
        },
        .mouse_scrolled => |e| {
            self.unimouse.scrolled(e); 
            (self.getMouse(e.mouse_id) orelse return).scrolled(e);
        },
        .mouse_moved => |e| {
            self.unimouse.moved(e); 
            (self.getMouse(e.mouse_id) orelse return).moved(e);
        },
        else => {}
    }
}

// Called at the start of every frame
pub fn tick(self: *Input) void {
    var ms_iter = self.mice.valueIterator();
    while (ms_iter.next()) |ms| {
        ms.resetDeltas();
    }
}

pub fn getKeyboard(self: *Input, id: usize) ?*devices.KeyboardDevice {
    return self.keyboards.getPtr(id);
}

pub fn getMouse(self: *Input, id: usize) ?*devices.MouseDevice {
    return self.mice.getPtr(id);
}

pub fn getGamepad(self: *Input, id: usize) ?*devices.GamepadDevice {
    return self.gamepads.getPtr(id);
}

pub fn getTouchDevice(self: *Input, id: usize) ?*devices.TouchDevice {
    return self.touch_devices.getPtr(id);
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

pub const registerLua = struct {
    const linker = @import("../scripting/linker/linker.zig");
    const Runtime = @import("../scripting/runtime/Runtime.zig");
    const zlua = @import("zlua");
    const KeyboardDeviceBind = linker.Binding(devices.KeyboardDevice, true);
    const MouseDeviceBind = linker.Binding(devices.MouseDevice, true);
    const InputBind = linker.Binding(Input, false);

    fn pushSignal(l: *zlua.Lua, sig: anytype) void {
        linker.util.pushVal(l, @TypeOf(sig), sig);
    }

    fn luaGet(l: *zlua.Lua) i32 {
        const r: *Runtime = .fromState(l);
        const self = r.input;
        const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });

        if (std.mem.eql(u8, key, "Keyboards")) {
            const unikeyboard = self.unikeyboard;

            l.newTable();
            pushSignal(l, &unikeyboard.key_pressed);
            l.setField(-2, "KeyPressed");
            pushSignal(l, &unikeyboard.key_released);
            l.setField(-2, "KeyReleased");
            pushSignal(l, &self.keyboard_connected);
            l.setField(-2, "Connected");
            pushSignal(l, &self.keyboard_disconnected);
            l.setField(-2, "Disconnected");

            return 1;
        } else if (std.mem.eql(u8, key, "Mice")) {
            const unimouse = self.unimouse;

            l.newTable();
            pushSignal(l, &unimouse.button_pressed);
            l.setField(-2, "ButtonPressed");
            pushSignal(l, &unimouse.button_released);
            l.setField(-2, "ButtonReleased");
            pushSignal(l, &unimouse.moved_evt);
            l.setField(-2, "Moved");
            pushSignal(l, &unimouse.scrolled_evt);
            l.setField(-2, "Scrolled");
            pushSignal(l, &self.mouse_connected);
            l.setField(-2, "Connected");
            pushSignal(l, &self.mouse_disconnected);
            l.setField(-2, "Disconnected");

            return 1;
        } else if (std.mem.eql(u8, key, "CursorLocked")) {
            l.pushBoolean(self.getCursorLocked());
            return 1;
        } else if (std.mem.eql(u8, key, "CursorVisible")) {
            l.pushBoolean(self.getCursorVisible());
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

    fn luaSet(l: *zlua.Lua) i32 {
        const r: *Runtime = .fromState(l);
        const self = r.input;
        const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });

        if (std.mem.eql(u8, key, "CursorLocked")) {
            l.checkType(3, .boolean);
            self.setCursorLocked(l.toBoolean(3));
            return 0;
        } else if (std.mem.eql(u8, key, "CursorVisible")) {
            l.checkType(3, .boolean);
            self.setCursorVisible(l.toBoolean(3));
            return 0;
        } else if (std.mem.eql(u8, key, "Keyboards")
            or std.mem.eql(u8, key, "Mice")
        ) {
            l.raiseErrorStr("'input.%s' is read-only", .{});
        } else {
            l.raiseErrorStr("'input.%s' doesn't exist", .{});
        }
    }

    fn luaGetKeyboard(l: *zlua.Lua) i32 {
        const r: *Runtime = .fromState(l);
        // Even though lua is 1-indexed, it'd be too much friction
        // to have to turn lua ids to/from zig ids every time we want
        // to deal with device IDs. A little inconsistency is worth it for maintainability
        const keyboard_id = l.checkInteger(2);
        if (keyboard_id < 0) l.raiseErrorStr("%d is not a valid keyboard ID", .{ keyboard_id });

        KeyboardDeviceBind.push(l, r.input.getKeyboard(@intCast(keyboard_id)) orelse l.raiseErrorStr("No keyboard of ID %d exists.", .{ keyboard_id }));
        return 1;
    }

    fn luaGetMouse(l: *zlua.Lua) i32 {
        const r: *Runtime = .fromState(l);
        const mouse_id = l.checkInteger(2);
        if (mouse_id < 0) l.raiseErrorStr("%d is not a valid mouse ID", .{ mouse_id });

        MouseDeviceBind.push(l, r.input.getMouse(@intCast(mouse_id)) orelse l.raiseErrorStr("No mouse of ID %d exists.", .{ mouse_id }));
        return 1;
    }

    pub fn registerLua(l: *zlua.Lua) void {
        linker.signal(l, signal.Signal(.{ *devices.KeyboardDevice }));
        linker.signal(l, signal.Signal(.{ *devices.MouseDevice }));
        linker.signal(l, signal.Signal(.{ *devices.GamepadDevice }));

        linker.module(l, .{
            .name = "input",
            .functions = &.{
                .custom("GetKeyboard", luaGetKeyboard),
                .custom("GetMouse", luaGetMouse)
            },
            .properties = .luaCustom(luaGet, luaSet),
        });
    }
}.registerLua;