// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const builtin = @import("builtin");
const objc = @import("objc");
const sdl3 = @import("sdl3");
const desc = @import("../desc.zig");
const types = @import("../types.zig");

const flags: sdl3.InitFlags = .{ .video = true };

const SdlBackend = @This();

pub fn init(_: SdlBackend) void {
    sdl3.init(flags) catch {
        std.log.err("Failed to init sdl3: {s}", .{ sdl3.errors.get() orelse "no error message" });
    };
}

pub fn deinit(_: SdlBackend) void {

    sdl3.quit(flags);
}

pub fn createSurface(_: SdlBackend, d: desc.SurfaceDesc) !types.SurfaceHandle {
    const w: sdl3.video.Window = try .init(
        d.title, 
        @intCast(d.width), 
        @intCast(d.height), 
        .{
            .metal = true, 
            .resizable = true 
        }
    );

    const props = try w.getProperties();
    const handle = if (props.android_window) |win| win.value
        else if (props.ui_kit_window) |win| win.value
        else if (props.cocoa_window != null) sdl3.c.SDL_Metal_CreateView(w.value)
        else if (props.vivante_window) |win| win.value
        else if (props.win32_hwnd) |win| win.value
        else if (props.wayland_viewport) |win| win.value
        else if (props.x11_display) |win| win.value
        else unreachable;
    
    return .{ .id = try w.getId(), .handle = handle };
}

pub fn getSurfacePixelSize(_: SdlBackend, h: types.SurfaceHandle) [2]u32 {
    const w = sdl3.video.Window.fromId(@intCast(h.id)) catch unreachable;
    const size = w.getSizeInPixels() catch unreachable;

    return .{ @intCast(size[0]), @intCast(size[1]) };
}

pub fn destroySurface(_: SdlBackend, h: types.SurfaceHandle) void {
    const w = sdl3.video.Window.fromId(@intCast(h.id)) catch unreachable;
    w.deinit();
}

pub fn pollEvent(_: SdlBackend) ?desc.PlatformEvent {
    const event = sdl3.events.poll() orelse return null;

    return switch (event) {
        .quit => return .quit,
        .window_resized => |e| return .{ .surface_resize = .{ 
            .width = @intCast(e.width), 
            .height = @intCast(e.height) 
        } },
        .keyboard_added => |e| return .{ .keyboard_connected = .{
            .id = e.id.value
        } },
        .keyboard_removed => |e| return .{ .keyboard_disconnected = .{
            .id = e.id.value
        } },
        .key_down => |e| return .{ .keyboard_key_down = .{ 
            .window_id = e.window_id orelse 0, 
            .keyboard_id = if (e.id) |id| id.value else 0,
            .repeat = e.repeat,
            .keycode = sdlKeycodeToPlatformKeycode(e.key)
        } },
        .key_up => |e| return .{ .keyboard_key_up = .{
            .window_id = e.window_id orelse 0, 
            .keyboard_id = if (e.id) |id| id.value else 0,
            .repeat = e.repeat,
            .keycode = sdlKeycodeToPlatformKeycode(e.key)
        } },
        .mouse_added => |e| return .{ .mouse_connected = .{
            .id = e.id.value
        } },
        .mouse_removed => |e| return .{ .mouse_disconnected = .{
            .id = e.id.value
        } },
        .mouse_button_down => |e| return .{ .mouse_button_down = .{
            .window_id = e.window_id orelse 0,
            .mouse_id = if (e.id) |id| id.value else 0,
            .button = sdlMouseButtonToPlatformMouseButton(e.button)
        } },
        .mouse_button_up => |e| return .{ .mouse_button_up = .{
            .window_id = e.window_id orelse 0,
            .mouse_id = if (e.id) |id| id.value else 0,
            .button = sdlMouseButtonToPlatformMouseButton(e.button)
        } },
        .mouse_motion => |e| return .{ .mouse_moved = .{
            .window_id = e.window_id orelse 0,
            .mouse_id = if (e.id) |id| id.value else 0,
            .position = .{ e.x, e.y },
            .delta = .{ e.x_rel, e.y_rel }
        } },
        .mouse_wheel => |e| return .{ .mouse_scrolled = .{
            .window_id = e.window_id orelse 0,
            .mouse_id = if (e.id) |id| id.value else 0,
            .delta = .{ e.scroll_x, e.scroll_y }
        } },
        .gamepad_added => |e| return .{ .gamepad_connected = .{
            .id = e.id.value
        } },
        .gamepad_removed => |e| return .{ .gamepad_disconnected = .{
            .id = e.id.value
        } },
        .gamepad_button_down => |e| return .{ .gamepad_button_down = .{
            .gamepad_id = e.id.value,
            .button = sdlGamepadButtonToPlatformGamepadButton(e.button),
        } },
        .gamepad_button_up => |e| return .{ .gamepad_button_up = .{
            .gamepad_id = e.id.value,
            .button = sdlGamepadButtonToPlatformGamepadButton(e.button),
        } },
        .gamepad_axis_motion => |e| return .{ .gamepad_axis_changed = .{
            .gamepad_id = e.id.value,
            .axis = sdlGamepadAxisToPlatformGamepadAxis(e.axis),
            .value = e.value
        } },
        else => null,
    };
}

pub fn showError(_: SdlBackend, msg: [:0]const u8) void {
    sdl3.message_box.showSimple(.{ .error_dialog = true }, "Sorry, something happened.", msg, null) catch {};
}

const KeyPair = struct { sdl: sdl3.keycode.Keycode, plat: desc.Keycode };
const key_pairs = [_]KeyPair{
    .{ .sdl = .return_key, .plat = .Return },
    .{ .sdl = .escape, .plat = .Escape },
    .{ .sdl = .backspace, .plat = .Backspace },
    .{ .sdl = .tab, .plat = .Tab },
    .{ .sdl = .space, .plat = .Space },
    .{ .sdl = .exclaim, .plat = .Exclaim },
    .{ .sdl = .dblapostrophe, .plat = .DoubleApostrophe },
    .{ .sdl = .hash, .plat = .Hash },
    .{ .sdl = .dollar, .plat = .Dollar },
    .{ .sdl = .percent, .plat = .Percent },
    .{ .sdl = .ampersand, .plat = .Ampersand },
    .{ .sdl = .apostrophe, .plat = .Apostrophe },
    .{ .sdl = .left_paren, .plat = .LeftParen },
    .{ .sdl = .right_paren, .plat = .RightParen },
    .{ .sdl = .asterisk, .plat = .Asterisk },
    .{ .sdl = .plus, .plat = .Plus },
    .{ .sdl = .comma, .plat = .Comma },
    .{ .sdl = .minus, .plat = .Minus },
    .{ .sdl = .period, .plat = .Period },
    .{ .sdl = .slash, .plat = .Slash },
    .{ .sdl = .zero, .plat = .Zero },
    .{ .sdl = .one, .plat = .One },
    .{ .sdl = .two, .plat = .Two },
    .{ .sdl = .three, .plat = .Three },
    .{ .sdl = .four, .plat = .Four },
    .{ .sdl = .five, .plat = .Five },
    .{ .sdl = .six, .plat = .Six },
    .{ .sdl = .seven, .plat = .Seven },
    .{ .sdl = .eight, .plat = .Eight },
    .{ .sdl = .nine, .plat = .Nine },
    .{ .sdl = .colon, .plat = .Colon },
    .{ .sdl = .semicolon, .plat = .Semicolon },
    .{ .sdl = .less, .plat = .Less },
    .{ .sdl = .equals, .plat = .Equals },
    .{ .sdl = .greater, .plat = .Greater },
    .{ .sdl = .question, .plat = .Question },
    .{ .sdl = .at, .plat = .At },
    .{ .sdl = .left_bracket, .plat = .LeftBracket },
    .{ .sdl = .backslash, .plat = .Backslash },
    .{ .sdl = .right_bracket, .plat = .RightBracket },
    .{ .sdl = .caret, .plat = .Caret },
    .{ .sdl = .underscore, .plat = .Underscore },
    .{ .sdl = .grave, .plat = .Grave },
    .{ .sdl = .a, .plat = .A },
    .{ .sdl = .b, .plat = .B },
    .{ .sdl = .c, .plat = .C },
    .{ .sdl = .d, .plat = .D },
    .{ .sdl = .e, .plat = .E },
    .{ .sdl = .f, .plat = .F },
    .{ .sdl = .g, .plat = .G },
    .{ .sdl = .h, .plat = .H },
    .{ .sdl = .i, .plat = .I },
    .{ .sdl = .j, .plat = .J },
    .{ .sdl = .k, .plat = .K },
    .{ .sdl = .l, .plat = .L },
    .{ .sdl = .m, .plat = .M },
    .{ .sdl = .n, .plat = .N },
    .{ .sdl = .o, .plat = .O },
    .{ .sdl = .p, .plat = .P },
    .{ .sdl = .q, .plat = .Q },
    .{ .sdl = .r, .plat = .R },
    .{ .sdl = .s, .plat = .S },
    .{ .sdl = .t, .plat = .T },
    .{ .sdl = .u, .plat = .U },
    .{ .sdl = .v, .plat = .V },
    .{ .sdl = .w, .plat = .W },
    .{ .sdl = .x, .plat = .X },
    .{ .sdl = .y, .plat = .Y },
    .{ .sdl = .z, .plat = .Z },
    .{ .sdl = .left_brace, .plat = .LeftBrace },
    .{ .sdl = .pipe, .plat = .Pipe },
    .{ .sdl = .right_brace, .plat = .RightBrace },
    .{ .sdl = .tilde, .plat = .Tilde },
    .{ .sdl = .delete, .plat = .Delete },
    .{ .sdl = .plus_minus, .plat = .PlusMinus },
    .{ .sdl = .caps_lock, .plat = .CapsLock },
    .{ .sdl = .func1, .plat = .F1 },
    .{ .sdl = .func2, .plat = .F2 },
    .{ .sdl = .func3, .plat = .F3 },
    .{ .sdl = .func4, .plat = .F4 },
    .{ .sdl = .func5, .plat = .F5 },
    .{ .sdl = .func6, .plat = .F6 },
    .{ .sdl = .func7, .plat = .F7 },
    .{ .sdl = .func8, .plat = .F8 },
    .{ .sdl = .func9, .plat = .F9 },
    .{ .sdl = .func10, .plat = .F10 },
    .{ .sdl = .func11, .plat = .F11 },
    .{ .sdl = .func12, .plat = .F12 },
    .{ .sdl = .print_screen, .plat = .PrintScreen },
    .{ .sdl = .scroll_lock, .plat = .ScrollLock },
    .{ .sdl = .pause, .plat = .Pause },
    .{ .sdl = .insert, .plat = .Insert },
    .{ .sdl = .home, .plat = .Home },
    .{ .sdl = .page_up, .plat = .PageUp },
    .{ .sdl = .end, .plat = .End },
    .{ .sdl = .page_down, .plat = .PageDown },
    .{ .sdl = .right, .plat = .Right },
    .{ .sdl = .left, .plat = .Left },
    .{ .sdl = .down, .plat = .Down },
    .{ .sdl = .up, .plat = .Up },
    .{ .sdl = .num_lock_clear, .plat = .NumLockClear },
    .{ .sdl = .kp_divide, .plat = .KeypadDivide },
    .{ .sdl = .kp_multiply, .plat = .KeypadMultiply },
    .{ .sdl = .kp_minus, .plat = .KeypadMinus },
    .{ .sdl = .kp_plus, .plat = .KeypadPlus },
    .{ .sdl = .kp_enter, .plat = .KeypadEnter },
    .{ .sdl = .kp_1, .plat = .Keypad1 },
    .{ .sdl = .kp_2, .plat = .Keypad2 },
    .{ .sdl = .kp_3, .plat = .Keypad3 },
    .{ .sdl = .kp_4, .plat = .Keypad4 },
    .{ .sdl = .kp_5, .plat = .Keypad5 },
    .{ .sdl = .kp_6, .plat = .Keypad6 },
    .{ .sdl = .kp_7, .plat = .Keypad7 },
    .{ .sdl = .kp_8, .plat = .Keypad8 },
    .{ .sdl = .kp_9, .plat = .Keypad9 },
    .{ .sdl = .kp_0, .plat = .Keypad0 },
    .{ .sdl = .kp_period, .plat = .KeypadPeriod },
    .{ .sdl = .application, .plat = .Application },
    .{ .sdl = .power, .plat = .Power },
    .{ .sdl = .kp_equals, .plat = .KeypadEquals },
    .{ .sdl = .func13, .plat = .F13 },
    .{ .sdl = .func14, .plat = .F14 },
    .{ .sdl = .func15, .plat = .F15 },
    .{ .sdl = .func16, .plat = .F16 },
    .{ .sdl = .func17, .plat = .F17 },
    .{ .sdl = .func18, .plat = .F18 },
    .{ .sdl = .func19, .plat = .F19 },
    .{ .sdl = .func20, .plat = .F20 },
    .{ .sdl = .func21, .plat = .F21 },
    .{ .sdl = .func22, .plat = .F22 },
    .{ .sdl = .func23, .plat = .F23 },
    .{ .sdl = .func24, .plat = .F24 },
    .{ .sdl = .execute, .plat = .Execute },
    .{ .sdl = .help, .plat = .Help },
    .{ .sdl = .menu, .plat = .Menu },
    .{ .sdl = .select, .plat = .Select },
    .{ .sdl = .stop, .plat = .Stop },
    .{ .sdl = .again, .plat = .Again },
    .{ .sdl = .undo, .plat = .Undo },
    .{ .sdl = .cut, .plat = .Cut },
    .{ .sdl = .copy, .plat = .Copy },
    .{ .sdl = .paste, .plat = .Paste },
    .{ .sdl = .find, .plat = .Find },
    .{ .sdl = .mute, .plat = .Mute },
    .{ .sdl = .volume_up, .plat = .VolumeUp },
    .{ .sdl = .volume_down, .plat = .VolumeDown },
    .{ .sdl = .kp_comma, .plat = .KeypadComma },
    .{ .sdl = .kp_equals_as_400, .plat = .KeypadEqualsAs400 },
    .{ .sdl = .alt_erase, .plat = .AltErase },
    .{ .sdl = .cancel, .plat = .Cancel },
    .{ .sdl = .clear, .plat = .Clear },
    .{ .sdl = .prior, .plat = .Prior },
    .{ .sdl = .separator, .plat = .Separator },
    .{ .sdl = .out, .plat = .Out },
    .{ .sdl = .oper, .plat = .Oper },
    .{ .sdl = .clear_again, .plat = .ClearAgain },
    .{ .sdl = .cr_sel, .plat = .CrSel },
    .{ .sdl = .ex_sel, .plat = .ExSel },
    .{ .sdl = .kp_00, .plat = .Keypad00 },
    .{ .sdl = .kp_000, .plat = .Keypad000 },
    .{ .sdl = .thousands_separator, .plat = .ThousandsSeparator },
    .{ .sdl = .decimal_separator, .plat = .DecimalSeparator },
    .{ .sdl = .currency_unit, .plat = .CurrencyUnit },
    .{ .sdl = .currency_subunit, .plat = .CurrencySubunit },
    .{ .sdl = .kp_left_paren, .plat = .KeypadLeftParen },
    .{ .sdl = .kp_right_paren, .plat = .KeypadRightParen },
    .{ .sdl = .kp_left_brace, .plat = .KeypadLeftBrace },
    .{ .sdl = .kp_right_brace, .plat = .KeypadRightBrace },
    .{ .sdl = .kp_tab, .plat = .KeypadTab },
    .{ .sdl = .kp_backspace, .plat = .KeypadBackspace },
    .{ .sdl = .kp_a, .plat = .KeypadA },
    .{ .sdl = .kp_b, .plat = .KeypadB },
    .{ .sdl = .kp_c, .plat = .KeypadC },
    .{ .sdl = .kp_d, .plat = .KeypadD },
    .{ .sdl = .kp_e, .plat = .KeypadE },
    .{ .sdl = .kp_f, .plat = .KeypadF },
    .{ .sdl = .kp_xor, .plat = .KeypadXor },
    .{ .sdl = .kp_power, .plat = .KeypadPower },
    .{ .sdl = .kp_percent, .plat = .KeypadPercent },
    .{ .sdl = .kp_less, .plat = .KeypadLess },
    .{ .sdl = .kp_greater, .plat = .KeypadGreater },
    .{ .sdl = .kp_ampersand, .plat = .KeypadAmpersand },
    .{ .sdl = .kp_dblampersand, .plat = .KeypadDoubleAmpersand },
    .{ .sdl = .kp_verticalbar, .plat = .KeypadVerticalbar },
    .{ .sdl = .kp_dbl_vertical_bar, .plat = .KeypadDoubleVerticalBar },
    .{ .sdl = .kp_colon, .plat = .KeypadColon },
    .{ .sdl = .kp_hash, .plat = .KeypadHash },
    .{ .sdl = .kp_space, .plat = .KeypadSpace },
    .{ .sdl = .kp_at, .plat = .KeypadAt },
    .{ .sdl = .kp_exclam, .plat = .KeypadExclam },
    .{ .sdl = .kp_mem_store, .plat = .KeypadMemStore },
    .{ .sdl = .kp_mem_recall, .plat = .KeypadMemRecall },
    .{ .sdl = .kp_mem_clear, .plat = .KeypadMemClear },
    .{ .sdl = .kp_mem_add, .plat = .KeypadMemAdd },
    .{ .sdl = .kp_mem_subtract, .plat = .KeypadMemSubtract },
    .{ .sdl = .kp_mem_multiply, .plat = .KeypadMemMultiply },
    .{ .sdl = .kp_mem_divide, .plat = .KeypadMemDivide },
    .{ .sdl = .kp_plus_minus, .plat = .KeypadPlusMinus },
    .{ .sdl = .kp_clear, .plat = .KeypadClear },
    .{ .sdl = .kp_clear_entry, .plat = .KeypadClearEntry },
    .{ .sdl = .kp_binary, .plat = .KeypadBinary },
    .{ .sdl = .kp_octal, .plat = .KeypadOctal },
    .{ .sdl = .kp_decimal, .plat = .KeypadDecimal },
    .{ .sdl = .kp_hexadecimal, .plat = .KeypadHexadecimal },
    .{ .sdl = .left_ctrl, .plat = .LeftCtrl },
    .{ .sdl = .left_shift, .plat = .LeftShift },
    .{ .sdl = .left_alt, .plat = .LeftAlt },
    .{ .sdl = .left_gui, .plat = .LeftGui },
    .{ .sdl = .right_ctrl, .plat = .RightCtrl },
    .{ .sdl = .right_shift, .plat = .RightShift },
    .{ .sdl = .right_alt, .plat = .RightAlt },
    .{ .sdl = .right_gui, .plat = .RightGui },
    .{ .sdl = .mode, .plat = .Mode },
    .{ .sdl = .sleep, .plat = .Sleep },
    .{ .sdl = .wake, .plat = .Wake },
    .{ .sdl = .channel_increment, .plat = .ChannelIncrement },
    .{ .sdl = .channel_decrement, .plat = .ChannelDecrement },
    .{ .sdl = .media_play, .plat = .MediaPlay },
    .{ .sdl = .media_pause, .plat = .MediaPause },
    .{ .sdl = .media_record, .plat = .MediaRecord },
    .{ .sdl = .media_fast_forward, .plat = .MediaFastForward },
    .{ .sdl = .media_rewind, .plat = .MediaRewind },
    .{ .sdl = .media_next_track, .plat = .MediaNextTrack },
    .{ .sdl = .media_previous_track, .plat = .MediaPreviousTrack },
    .{ .sdl = .media_stop, .plat = .MediaStop },
    .{ .sdl = .media_eject, .plat = .MediaEject },
    .{ .sdl = .media_play_pause, .plat = .MediaPlayPause },
    .{ .sdl = .media_select, .plat = .MediaSelect },
    .{ .sdl = .ac_new, .plat = .AcNew },
    .{ .sdl = .ac_open, .plat = .AcOpen },
    .{ .sdl = .ac_close, .plat = .AcClose },
    .{ .sdl = .ac_exit, .plat = .AcExit },
    .{ .sdl = .ac_save, .plat = .AcSave },
    .{ .sdl = .ac_print, .plat = .AcPrint },
    .{ .sdl = .ac_properties, .plat = .AcProperties },
    .{ .sdl = .ac_search, .plat = .AcSearch },
    .{ .sdl = .ac_home, .plat = .AcHome },
    .{ .sdl = .ac_back, .plat = .AcBack },
    .{ .sdl = .ac_forward, .plat = .AcForward },
    .{ .sdl = .ac_stop, .plat = .AcStop },
    .{ .sdl = .ac_refresh, .plat = .AcRefresh },
    .{ .sdl = .ac_bookmarks, .plat = .AcBookmarks },
    .{ .sdl = .soft_left, .plat = .SoftLeft },
    .{ .sdl = .soft_right, .plat = .SoftRight },
    .{ .sdl = .call, .plat = .Call },
    .{ .sdl = .end_call, .plat = .EndCall },
    .{ .sdl = .left_tab, .plat = .LeftTab },
    .{ .sdl = .level5_shift, .plat = .Level5Shift },
    .{ .sdl = .multi_key_compose, .plat = .MultiKeyCompose },
    .{ .sdl = .left_meta, .plat = .LeftMeta },
    .{ .sdl = .right_meta, .plat = .RightMeta },
    .{ .sdl = .left_hyper, .plat = .LeftHyper },
    .{ .sdl = .right_hyper, .plat = .RightHyper }
};

fn sdlKeycodeToPlatformKeycode(keycode: ?sdl3.keycode.Keycode) desc.Keycode {
    if (keycode == null) return .Unknown;
    inline for (key_pairs) |p| if (p.sdl == keycode.?) return p.plat;
    
    return .Unknown;
}

fn platformKeycodeToSdlKeycode(keycode: desc.Keycode) ?sdl3.keycode.Keycode {
    inline for (key_pairs) |p| if (p.plat == keycode) return p.sdl;

    return null;
}

const MousePair = struct { sdl: sdl3.mouse.Button, plat: desc.MouseButton };
const mouse_pairs = [_]MousePair{
    .{ .sdl = .left, .plat = .Left },
    .{ .sdl = .middle, .plat = .Middle },
    .{ .sdl = .right, .plat = .Right },
    .{ .sdl = .x1, .plat = .SideButtonBack },
    .{ .sdl = .x2, .plat = .SideButtonForwards }
};

fn sdlMouseButtonToPlatformMouseButton(button: sdl3.mouse.Button) desc.MouseButton {
    inline for (mouse_pairs) |p| if (p.sdl == button) return p.plat;
    unreachable;
}

fn platformMouseButtonToSdlMouseButton(button: desc.MouseButton) sdl3.mouse.Button {
    inline for (mouse_pairs) |p| if (p.plat == button) return p.sdl;
    unreachable;
}

const GamepadButtonPair = struct { sdl: sdl3.gamepad.Button, plat: desc.GamepadButton };
const gamepad_button_pairs = [_]GamepadButtonPair{
    .{ .sdl = .north, .plat = .North },
    .{ .sdl = .south, .plat = .South },
    .{ .sdl = .east, .plat = .East },
    .{ .sdl = .west, .plat = .West },
    .{ .sdl = .dpad_up, .plat = .DPadUp },
    .{ .sdl = .dpad_down, .plat = .DPadDown },
    .{ .sdl = .dpad_left, .plat = .DPadLeft },
    .{ .sdl = .dpad_right, .plat = .DPadRight },
    .{ .sdl = .left_stick, .plat = .LeftStickClick },
    .{ .sdl = .right_stick, .plat = .RightStickClick },
    .{ .sdl = .touchpad, .plat = .TouchpadClick },
    .{ .sdl = .left_shoulder, .plat = .LeftShoulder },
    .{ .sdl = .right_shoulder, .plat = .RightShoulder },
    .{ .sdl = .start, .plat = .Start },
    .{ .sdl = .guide, .plat = .Guide },
    .{ .sdl = .back, .plat = .Select },
    // While a misc button, it's commonly utilized on many controllers,
    // like Share on xbox X/S, Mic/Mute on dualsense, Quick Access on steam controller, etc.
    .{ .sdl = .misc1, .plat = .Utility },
    .{ .sdl = .left_paddle1, .plat = .TopLeftPaddle },
    .{ .sdl = .left_paddle2, .plat = .BottomLeftPaddle },
    .{ .sdl = .right_paddle1, .plat = .TopRightPaddle },
    .{ .sdl = .right_paddle2, .plat = .BottomRightPaddle }
};

fn sdlGamepadButtonToPlatformGamepadButton(button: sdl3.gamepad.Button) desc.GamepadButton {
    inline for (gamepad_button_pairs) |p| if (p.sdl == button) return p.plat;
    unreachable;
}

fn platformGamepadButtonToSdlGamepadButton(button: desc.GamepadButton) sdl3.gamepad.Button {
    inline for (gamepad_button_pairs) |p| if (p.plat == button) return p.sdl;
    unreachable;
}

const GamepadAxisPair = struct { sdl: sdl3.gamepad.Axis, plat: desc.GamepadAxis };
const gamepad_axis_pairs = [_]GamepadAxisPair{
    .{ .sdl = .left_trigger, .plat = .LeftTrigger },
    .{ .sdl = .right_trigger, .plat = .RightTrigger },
    .{ .sdl = .left_x, .plat = .LeftStickX },
    .{ .sdl = .left_y, .plat = .LeftStickY },
    .{ .sdl = .right_x, .plat = .RightStickX },
    .{ .sdl = .right_y, .plat = .RightStickY }
};

fn sdlGamepadAxisToPlatformGamepadAxis(axis: sdl3.gamepad.Axis) desc.GamepadAxis {
    inline for (gamepad_axis_pairs) |p| if (p.sdl == axis) return p.plat;
    unreachable;
}

fn platformGamepadAxisToSdlGamepadAxis(axis: desc.GamepadAxis) sdl3.gamepad.Axis {
    inline for (gamepad_axis_pairs) |p| if (p.plat == axis) return p.sdl;
    unreachable;
}