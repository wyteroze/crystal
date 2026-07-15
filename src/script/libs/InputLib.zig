// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const Callback = @import("../shared.zig").Callback;
const types = @import("../../types.zig");
const Vec2_SIMD = types.Vec2_SIMD;
const Vec3 = @import("../objects/Vec3.zig").Vec3;
const InputEvent = @import("../objects/InputEvent.zig").InputEvent;
const keycode = sdl3.keycode;

pub const InputCode = enum {
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
    Exclamation, At, Hashtag, Dollar, Percent, Caret, Ampersand, Asterisk, LeftParen, RightParen,
    Plus, Minus, Underscore, Equal,
    LeftBrace, RightBrace, LeftBracket, RightBracket, Pipe, Slash, Backslash, Colon, Semicolon, Quote, DoubleQuote,
    Comma, Period, LessThan, GreaterThan, Question, Tilde, Backquote,
    Escape, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, Tab, Backspace, CapsLock, Enter,
    LeftShift, RightShift, LeftControl, RightControl, LeftAlt, RightAlt, LeftSuper, RightSuper,
    Up, Down, Left, Right,
    LeftMouseButton, RightMouseButton, MiddleMouseButton, MouseScroll, MouseMove, Space,

    pub fn name(self: InputCode) [:0]const u8 {
        return switch (self) {
            .A => "A", .B => "B", .C => "C", .D => "D", .E => "E", .F => "F", .G => "G", .H => "H",
            .I => "I", .J => "J", .K => "K", .L => "L", .M => "M", .N => "N", .O => "O", .P => "P",
            .Q => "Q", .R => "R", .S => "S", .T => "T", .U => "U", .V => "V", .W => "W", .X => "X",
            .Y => "Y", .Z => "Z",
            .Exclamation => "Exclamation", .At => "At", .Hashtag => "Hashtag", .Dollar => "Dollar",
            .Percent => "Percent", .Caret => "Caret", .Ampersand => "Ampersand", .Asterisk => "Asterisk",
            .LeftParen => "LeftParen", .RightParen => "RightParen", .Plus => "Plus", .Minus => "Minus",
            .Underscore => "Underscore", .Equal => "Equal",
            .LeftBrace => "LeftBrace", .RightBrace => "RightBrace", .LeftBracket => "LeftBracket",
            .RightBracket => "RightBracket", .Pipe => "Pipe", .Slash => "Slash", .Backslash => "Backslash",
            .Colon => "Colon", .Semicolon => "Semicolon", .Quote => "Quote", .DoubleQuote => "DoubleQuote",
            .Comma => "Comma", .Period => "Period", .LessThan => "LessThan", .GreaterThan => "GreaterThan",
            .Question => "Question", .Tilde => "Tilde", .Backquote => "Backquote",
            .Escape => "Escape", .F1 => "F1", .F2 => "F2", .F3 => "F3", .F4 => "F4", .F5 => "F5",
            .F6 => "F6", .F7 => "F7", .F8 => "F8", .F9 => "F9", .F10 => "F10", .F11 => "F11", .F12 => "F12",
            .Tab => "Tab", .Backspace => "Backspace", .CapsLock => "CapsLock", .Enter => "Enter",
            .LeftShift => "LeftShift", .RightShift => "RightShift", .LeftControl => "LeftControl",
            .RightControl => "RightControl", .LeftAlt => "LeftAlt", .RightAlt => "RightAlt",
            .LeftSuper => "LeftSuper", .RightSuper => "RightSuper",
            .Up => "Up", .Down => "Down", .Left => "Left", .Right => "Right",
            .LeftMouseButton => "LeftMouseButton", .RightMouseButton => "RightMouseButton",
            .MiddleMouseButton => "MiddleMouseButton", .MouseScroll => "MouseScroll", .MouseMove => "MouseMove",
            .Space => "Space"
        };
    }

    pub fn fromString(s: []const u8) ?InputCode {
        return code_map.get(s);
    }
};

const code_map = std.StaticStringMap(InputCode).initComptime(blk: {
    const fields = std.meta.fields(InputCode);
    var entries: [fields.len]struct { []const u8, InputCode } = undefined;
    for (fields, 0..) |f, i| {
        entries[i] = .{ f.name, @field(InputCode, f.name) };
    }

    break :blk entries;
});

pub fn fromSdlKeyCode(sc: ?sdl3.keycode.Keycode) ?InputCode {
    if (sc == null) return null;

    return switch (sc.?) {
        .a => .A, .b => .B, .c => .C, .d => .D, .e => .E, .f => .F, .g => .G, .h => .H,
        .i => .I, .j => .J, .k => .K, .l => .L, .m => .M, .n => .N, .o => .O, .p => .P,
        .q => .Q, .r => .R, .s => .S, .t => .T, .u => .U, .v => .V, .w => .W, .x => .X,
        .y => .Y, .z => .Z,
        .escape => .Escape,
        .func1 => .F1, .func2 => .F2, .func3 => .F3, .func4 => .F4, .func5 => .F5, .func6 => .F6,
        .func7 => .F7, .func8 => .F8, .func9 => .F9, .func10 => .F10, .func11 => .F11, .func12 => .F12,
        .tab => .Tab, .backspace => .Backspace, .caps_lock => .CapsLock, .return_key => .Enter,
        .left_shift => .LeftShift, .right_shift => .RightShift,
        .left_ctrl => .LeftControl, .right_ctrl => .RightControl,
        .left_alt => .LeftAlt, .right_alt => .RightAlt,
        .left_gui => .LeftSuper, .right_gui => .RightSuper,
        .up => .Up, .down => .Down, .left => .Left, .right => .Right,
        .comma => .Comma, .period => .Period, .semicolon => .Semicolon, .apostrophe => .Quote,
        .left_bracket => .LeftBracket, .right_bracket => .RightBracket,
        .backslash => .Backslash, .slash => .Slash, .grave => .Backquote,
        .minus => .Minus, .equals => .Equal, .space => .Space,
        .pipe => .Pipe, .tilde => .Tilde, .exclaim => .Exclamation, .at => .At, .hash => .Hashtag,
        .dollar => .Dollar, .percent => .Percent, .caret => .Caret, .ampersand => .Ampersand,
        .asterisk => .Asterisk, .left_paren => .LeftParen, .right_paren => .RightParen,
        .underscore => .Underscore, .plus => .Plus, .left_brace => .LeftBrace, .right_brace => .RightBrace,
        .colon => .Colon, .dblapostrophe => .DoubleQuote, .greater => .GreaterThan, .less => .LessThan,
        .question => .Question,
        else => null,
    };
}

pub fn fromMouseButton(button: sdl3.mouse.Button) ?InputCode {
    return switch (button) {
        .left => .LeftMouseButton,
        .right => .RightMouseButton,
        .middle => .MiddleMouseButton,
        else => null,
    };
}

pub const InputValue = union(enum) { scalar: f32, vec2: Vec2_SIMD };
const Binding = struct { phase: enum { begin, end, change }, code: InputCode, cb: Callback };

pub const InputState = struct {
    allocator: std.mem.Allocator,
    window: sdl3.video.Window,
    bindings: std.ArrayList(Binding),
    down: std.AutoHashMap(InputCode, InputValue),

    fn fire(self: *InputState, phase: anytype, code: InputCode, ev: InputEvent) void {
        for (self.bindings.items) |b| {
            if (b.phase == phase and b.code == code) b.cb.call(.{ev});
        }
    }

    pub fn dispatch(self: *InputState, event: sdl3.events.Event) void {
        switch (event) {
            .key_down => |k| if (!k.repeat) if (fromSdlKeyCode(k.key)) |code| {
                self.down.put(code, .{ .scalar = 1 }) catch {};
                self.fire(.begin, code, .{ .code = code, .value = .{ .scalar = 1 }, .delta = .{ .vec = .{0,0,0} } });
            },
            .key_up => |k| if (fromSdlKeyCode(k.key)) |code| {
                _ = self.down.remove(code);
                self.fire(.end, code, .{ .code = code, .value = .{ .scalar = 0 }, .delta = .{ .vec = .{0,0,0} } });
            },
            .mouse_button_down => |m| if (fromMouseButton(m.button)) |code| {
                self.down.put(code, .{ .scalar = 1 }) catch {};
                self.fire(.begin, code, .{ .code = code, .value = .{ .scalar = 1 }, .delta = .{ .vec = .{0,0,0} } });
            },
            .mouse_button_up => |m| if (fromMouseButton(m.button)) |code| {
                _ = self.down.remove(code);
                self.fire(.end, code, .{ .code = code, .value = .{ .scalar = 0 }, .delta = .{ .vec = .{0,0,0} } });
            },
            .mouse_motion => |m| {
                const delta = Vec3{ .vec = .{ m.x_rel, m.y_rel, 0 } };
                self.fire(.change, .MouseMove, .{ .code = .MouseMove, .value = .{ .vec2 = .{ m.x, m.y } }, .delta = delta });
            },
            .mouse_wheel => |w| {
                const delta = Vec3{ .vec = .{ w.scroll_x, w.scroll_y, 0 } };
                self.fire(.change, .MouseScroll, .{ .code = .MouseScroll, .value = .{ .scalar = w.scroll_y }, .delta = delta });
            },
            else => {},
        }
    }

    pub fn deinit(self: *InputState) void {
        for (self.bindings.items) |b| b.cb.deinit();
        self.bindings.deinit(self.allocator);
        self.down.deinit();
    }
};

pub var current: ?*InputState = null;

pub const InputLib = struct {
    pub const name = "Input";
    pub const hidden = .{ "state" };
    state: *InputState,

    pub fn init(allocator: std.mem.Allocator, window: sdl3.video.Window) !InputLib {
        const st = try allocator.create(InputState);
        st.* = .{ .allocator = allocator, .window = window, .bindings = .empty, .down = .init(allocator) };
        current = st;

        return .{ .state = st };
    }

    pub fn deinit(self: *InputLib) void {
        self.state.deinit();
        self.state.allocator.destroy(self.state);
        current = null;
    }

    fn bind(self: *InputLib, phase: anytype, code: InputCode, cb: Callback) !void {
        try self.state.bindings.append(self.state.allocator, .{ .phase = phase, .code = code, .cb = cb });
    }
    pub fn OnBegin(self: *InputLib, code: InputCode, cb: Callback) !void { try self.bind(.begin, code, cb); }
    pub fn OnEnd(self: *InputLib, code: InputCode, cb: Callback) !void { try self.bind(.end, code, cb); }
    pub fn OnChange(self: *InputLib, code: InputCode, cb: Callback) !void { try self.bind(.change, code, cb); }

    pub fn IsDown(self: *InputLib, code: InputCode) bool { return self.state.down.contains(code); }
    pub fn GetValue(self: *InputLib, code: InputCode) f32 {
        return if (self.state.down.get(code)) |v| switch (v) { .scalar => |s| s, .vec2 => 0 } else 0;
    }

    pub fn setMouseVisible(_: *InputLib, visible: bool) !void {
        if (visible) try sdl3.mouse.show() else try sdl3.mouse.hide();
    }
    pub fn setMouseLocked(self: *InputLib, locked: bool) !void {
        try sdl3.mouse.setWindowRelativeMode(self.state.window, locked);
    }
};
