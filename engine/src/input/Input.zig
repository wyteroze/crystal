// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const devices = @import("devices/devices.zig");
const signal = @import("../core/signal.zig");
const Platform = @import("../platform/Platform.zig");

const usize_maxint = std.math.maxInt(usize);

const Input = @This();
allocator: std.mem.Allocator,
platform: *Platform,

// this sucks.. TODO: make this not suck
platform_event_con: signal.SignalConnection(signal.Signal(.{ Platform.desc.PlatformEvent })),

keyboard_connected: signal.Signal(.{ *devices.KeyboardDevice }),
keyboard_disconnected: signal.Signal(.{ *devices.KeyboardDevice }),

unikeyboard: *devices.KeyboardDevice,
unimouse: *devices.MouseDevice,
unigamepad: *devices.GamepadDevice,
unitouchdevice: *devices.TouchDevice,
keyboards: std.AutoHashMap(usize, devices.KeyboardDevice),
mice: std.AutoHashMap(usize, devices.MouseDevice),
gamepads: std.AutoHashMap(usize, devices.GamepadDevice),
touch_devices: std.AutoHashMap(usize, devices.TouchDevice),

pub fn init(self: *Input, allocator: std.mem.Allocator, platform: *Platform) !void {
    var keyboards: std.AutoHashMap(usize, devices.KeyboardDevice) = .init(allocator);
    var mice: std.AutoHashMap(usize, devices.MouseDevice) = .init(allocator);
    var gamepads: std.AutoHashMap(usize, devices.GamepadDevice) = .init(allocator);
    var touch_devices: std.AutoHashMap(usize, devices.TouchDevice) = .init(allocator);

    // These devices represent every input of that category.
    // No matter an input's ID, it always goes to both its device, and this device.
    // Mainly for listening to events regardless of what device they're from
    try keyboards.put(usize_maxint, .init(allocator, usize_maxint));
    try mice.put(usize_maxint, .init(allocator));
    try gamepads.put(usize_maxint, .init(allocator));
    try touch_devices.put(usize_maxint, .init(allocator));

    const platform_event_con = try platform.platform_event.connect(onPlatformEvent, self);

    self.* = .{
        .allocator = allocator,
        .platform = platform,
        .platform_event_con = platform_event_con,
        .keyboards = keyboards,
        .mice = mice,
        .gamepads = gamepads,
        .touch_devices = touch_devices,
        .unikeyboard = keyboards.getPtr(usize_maxint).?,
        .unimouse = mice.getPtr(usize_maxint).?,
        .unigamepad = gamepads.getPtr(usize_maxint).?,
        .unitouchdevice = touch_devices.getPtr(usize_maxint).?,
        .keyboard_connected = .init(allocator),
        .keyboard_disconnected = .init(allocator)
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
}

fn onPlatformEvent(self: *Input, event: Platform.desc.PlatformEvent) void {
    switch (event) {
        .keyboard_connected => |e| { 
            self.keyboards.put(@intCast(e.id), .init(self.allocator, e.id)) catch |err| @panic(@errorName(err)); 
            self.keyboard_connected.fire(.{ self.getKeyboard(e.id).? });
        },
        .keyboard_disconnected => |e| { 
            var kb = self.keyboards.fetchRemove(@intCast(e.id))
                orelse { std.log.err("Attempt to disconnect kb id {d}, but it doesn't exist/isn't registered", .{ e.id }); return; };
            
            self.keyboard_disconnected.fire(.{ &kb.value });
        },
        .keyboard_key_down => |e| { 
            self.unikeyboard.keyPressed(e); (self.getKeyboard(e.keyboard_id) orelse return).keyPressed(e); 
        },
        .keyboard_key_up => |e| { 
            self.unikeyboard.keyReleased(e); (self.getKeyboard(e.keyboard_id) orelse return).keyReleased(e); 
        },
        else => {}
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

pub const registerLua = struct {
    const linker = @import("../scripting/linker/linker.zig");
    const Runtime = @import("../scripting/runtime/Runtime.zig");
    const zlua = @import("zlua");
    const KeyboardDeviceBind = linker.Binding(devices.KeyboardDevice, true);
    const InputBind = linker.Binding(Input, false);

    fn luaGet(l: *zlua.Lua) i32 {
        const r: *Runtime = .fromState(l);
        const self = r.input;
        const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });

        if (std.mem.eql(u8, key, "Keyboards")) {
            const unikeyboard = self.unikeyboard;

            l.newTable();
            linker.util.pushVal(l, *signal.Signal(.{ Platform.desc.Keycode }), &unikeyboard.key_pressed);
            l.setField(-2, "KeyPressed");
            linker.util.pushVal(l, *signal.Signal(.{ Platform.desc.Keycode }), &unikeyboard.key_released);
            l.setField(-2, "KeyReleased");
            linker.util.pushVal(l, *signal.Signal(.{ *devices.KeyboardDevice }), &self.keyboard_connected);
            l.setField(-2, "Connected");
            linker.util.pushVal(l, *signal.Signal(.{ *devices.KeyboardDevice }), &self.keyboard_disconnected);
            l.setField(-2, "Disconnected");

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
        l.raiseErrorStr("'input' is read-only", .{});
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

    pub fn registerLua(l: *zlua.Lua) void {
        linker.signal(l, signal.Signal(.{ *devices.KeyboardDevice }));
        linker.module(l, .{
            .name = "input",
            .functions = &.{
                .custom("GetKeyboard", luaGetKeyboard)
            },
            .properties = .luaCustom(luaGet, luaSet),
        });
    }
}.registerLua;