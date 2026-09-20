// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub const SurfaceDesc = struct {
    title: [:0]const u8,
    width: u32,
    height: u32,
    target: enum { primary, secondary }
};

// Keyboard input
pub const KeyboardEvent = struct {
    keyboard_id: u32,
    window_id: u32,
    repeat: bool,
    keycode: Keycode,
};

pub const KeyboardConnectionEvent = struct {
    id: u32,
};

pub const Keycode = enum {
    Return, Escape, Backspace, Tab, Space,
    Exclaim, DoubleApostrophe, Hash, Dollar, Percent, Ampersand, Apostrophe,
    LeftParen, RightParen, Asterisk, Plus, Comma, Minus, Period, Slash,
    Zero, One, Two, Three, Four, Five, Six, Seven, Eight, Nine,
    Colon, Semicolon, Less, Equals, Greater, Question, At,
    LeftBracket, Backslash, RightBracket, Caret, Underscore, Grave,
    A, B, C, D, E, F, G, H, I, J, K, L, M,
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
    LeftBrace, Pipe, RightBrace, Tilde, Delete, PlusMinus, CapsLock,
    F1, F2, F3, F4, F5, F6,
    F7, F8, F9, F10, F11, F12,
    PrintScreen, ScrollLock, Pause, Insert,
    Home, PageUp, End, PageDown, Right, Left, Down, Up,
    NumLockClear, KeypadDivide, KeypadMultiply, KeypadMinus, KeypadPlus, KeypadEnter,
    Keypad1, Keypad2, Keypad3, Keypad4, Keypad5,
    Keypad6, Keypad7, Keypad8, Keypad9, Keypad0,
    KeypadPeriod, Application, Power, KeypadEquals,
    F13, F14, F15, F16, F17, F18,
    F19, F20, F21, F22, F23, F24,
    Execute, Help, Menu, Select, Stop, Again, Undo, Cut, Copy, Paste, Find,
    Mute, VolumeUp, VolumeDown, KeypadComma, KeypadEqualsAs400,
    AltErase, Cancel, Clear, Prior, Separator, Out, Oper, ClearAgain, CrSel, ExSel,
    Keypad00, Keypad000, ThousandsSeparator, DecimalSeparator, CurrencyUnit, CurrencySubunit,
    KeypadLeftParen, KeypadRightParen, KeypadLeftBrace, KeypadRightBrace,
    KeypadTab, KeypadBackspace, KeypadA, KeypadB, KeypadC, KeypadD, KeypadE, KeypadF,
    KeypadXor, KeypadPower, KeypadPercent, KeypadLess, KeypadGreater,
    KeypadAmpersand, KeypadDoubleAmpersand, KeypadVerticalbar, KeypadDoubleVerticalBar,
    KeypadColon, KeypadHash, KeypadSpace, KeypadAt, KeypadExclam,
    KeypadMemStore, KeypadMemRecall, KeypadMemClear,
    KeypadMemAdd, KeypadMemSubtract, KeypadMemMultiply, KeypadMemDivide,
    KeypadPlusMinus, KeypadClear, KeypadClearEntry,
    KeypadBinary, KeypadOctal, KeypadDecimal, KeypadHexadecimal,
    LeftCtrl, LeftShift, LeftAlt, LeftGui,
    RightCtrl, RightShift, RightAlt, RightGui,
    Mode, Sleep, Wake, ChannelIncrement, ChannelDecrement,
    MediaPlay, MediaPause, MediaRecord, MediaFastForward, MediaRewind,
    MediaNextTrack, MediaPreviousTrack, MediaStop, MediaEject, MediaPlayPause, MediaSelect,
    AcNew, AcOpen, AcClose, AcExit, AcSave, AcPrint,
    AcProperties, AcSearch, AcHome, AcBack, AcForward, AcStop, AcRefresh, AcBookmarks,
    SoftLeft, SoftRight, Call, EndCall,
    LeftTab, Level5Shift, MultiKeyCompose,
    LeftMeta, RightMeta, LeftHyper, RightHyper,
    Unknown,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        try writer.print("Keycode '{s:0}'", .{ @tagName(self) });
    }
};

// Mouse input
pub const MouseButtonEvent = struct {
    window_id: u32,
    mouse_id: u32,
    button: MouseButton
};

pub const MouseMoveEvent = struct {
    window_id: u32,
    mouse_id: u32,
    position: [2]f32,
    delta: [2]f32
};

pub const MouseScrollEvent = struct {
    window_id: u32,
    mouse_id: u32,
    delta: [2]f32
};

pub const MouseConnectionEvent = struct {
    id: u32,
};

pub const MouseButton = enum {
    Left,
    Middle,
    Right,
    SideButtonBack,
    SideButtonForwards
};

// Gamepad input
pub const GamepadButtonEvent = struct {
    gamepad_id: u32,
    button: GamepadButton
};

pub const GamepadAxisEvent = struct {
    gamepad_id: u32,
    axis: GamepadAxis,
    value: i16
};

pub const GamepadButton = enum {
    North, South, East, West,
    DPadUp, DPadDown, DPadLeft, DPadRight,
    LeftStickClick, RightStickClick,
    TouchpadClick,
    LeftShoulder, RightShoulder,
    Start, Guide, Select,
    Utility,
    TopLeftPaddle, TopRightPaddle,
    BottomLeftPaddle, BottomRightPaddle,
};

pub const GamepadAxis = enum {
    LeftTrigger,
    RightTrigger,
    LeftStickX,
    LeftStickY,
    RightStickX,
    RightStickY
};

pub const GamepadConnectionEvent = struct {
    id: u32,
};

pub const PlatformEvent = union(enum) {
    quit: void,
    surface_resize: struct { width: u32, height: u32 },
    keyboard_connected: KeyboardConnectionEvent,
    keyboard_disconnected: KeyboardConnectionEvent,
    keyboard_key_down: KeyboardEvent,
    keyboard_key_up: KeyboardEvent,
    mouse_connected: MouseConnectionEvent,
    mouse_disconnected: MouseConnectionEvent,
    mouse_button_down: MouseButtonEvent,
    mouse_button_up: MouseButtonEvent,
    mouse_moved: MouseMoveEvent,
    mouse_scrolled: MouseScrollEvent,
    gamepad_connected: GamepadConnectionEvent,
    gamepad_disconnected: GamepadConnectionEvent,
    gamepad_button_down: GamepadButtonEvent,
    gamepad_button_up: GamepadButtonEvent,
    gamepad_axis_changed: GamepadAxisEvent,
};
