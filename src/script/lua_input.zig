// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const sdl3 = @import("sdl3");
const types = @import("../types.zig");
const lua_vec = @import("lua_vec.zig");
const LuaSignal = @import("shared/Signal.zig").LuaSignal;
const Platform = @import("../Platform.zig").Platform;
const log = @import("../log.zig").lua;
const Lua = zlua.Lua;
const Vec2_SIMD = types.Vec2_SIMD;

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

pub const InputValue = union(enum) {
    scalar: f32,
    vec2: Vec2_SIMD
};

var allocator: std.mem.Allocator = undefined;
var down_state: std.AutoHashMap(InputCode, InputValue) = undefined;
var window: sdl3.video.Window = undefined;

const InputArgs = struct {
    code: InputCode,
    value: InputValue,
    delta: InputValue,
    user_index: i32
};
const InputSignal = LuaSignal(InputArgs, InputCode);

var begin_signal: InputSignal = undefined;
var end_signal: InputSignal = undefined;
var change_signal: InputSignal = undefined;

fn pushInputArgs(l: *Lua, args: InputArgs) i32 {
    pushInputTable(l, args.code, args.value, args.delta, args.user_index);
    return 1;
}

pub fn pushInputTable(l: *Lua, code: InputCode, value: InputValue, delta: InputValue, user_index: i32) void {
    l.newTable();

    _ = l.pushString(code.name());
    l.setField(-2, "Code");

    switch (value) {
        .scalar => |s| l.pushNumber(s),
        .vec2 => |v| lua_vec.pushVec2(l, v)
    }
    l.setField(-2, "Value");

    switch (delta) {
        .scalar => |s| l.pushNumber(s),
        .vec2 => |v| lua_vec.pushVec2(l, v)
    }
    l.setField(-2, "Delta");

    l.pushInteger(user_index);
    l.setField(-2, "UserIndex");
}

pub fn fireBegin(code: InputCode, value: InputValue, user_index: i32) void {
    down_state.put(code, value) catch {};
    begin_signal.fire(.{
        .code = code,
        .value = value,
        .delta = .{ .scalar = 0 },
        .user_index = user_index
    }, code, pushInputArgs, "Input.OnBegin");
}

pub fn fireEnd(code: InputCode, user_index: i32) void {
    _ = down_state.remove(code);
    end_signal.fire(.{
        .code = code,
        .value = .{ .scalar = 0 },
        .delta = .{ .scalar = 0 },
        .user_index = user_index
    }, code, pushInputArgs, "Input.OnEnd");
}

pub fn fireChange(code: InputCode, value: InputValue, delta: InputValue, user_index: i32) void {
    down_state.put(code, value) catch {};
    change_signal.fire(.{
        .code = code,
        .value = value,
        .delta = delta,
        .user_index = user_index
    }, code, pushInputArgs, "Input.OnChange");
}

fn parseCodeArg(l: *Lua, index: i32) ?InputCode {
    const s = l.checkString(index);
    const code = InputCode.fromString(s);
    if (code == null) {
        l.raiseErrorStr("invalid input code '%s'", .{ s.ptr });
    }

    return code;
}

fn inputIndex(l: *Lua) i32 {
    const key = l.checkString(2);

    // TODO: move to sdl3, better zig bindings and software rendering
    // performance plus we won't need to deal with this type of stuff
    if (std.mem.eql(u8, key, "MouseLocked")) {
        log.warn("Input.MouseLocked always returns false due to SDL issues", .{});

        l.pushBoolean(false);
        return 1;
    } else if (std.mem.eql(u8, key, "MouseVisible")) {
        log.warn("Input.MouseVisible always returns false due to SDL issues", .{});

        l.pushBoolean(false);
        return 1;
    }

    l.raiseErrorStr("no property named '%s' exists", .{ key.ptr });
    return 0;
}

fn inputNewIndex(l: *Lua) i32 {
    const key = l.checkString(2);
    if (std.mem.eql(u8, key, "MouseLocked")) {
        const locked = l.toBoolean(3);
        sdl3.mouse.setWindowRelativeMode(window, locked) catch {
            l.raiseErrorStr("failed to set mouse lock to '%s'", .{ locked });
            return 0;
        };

        return 0;
    } else if (std.mem.eql(u8, key, "MouseVisible")) {
        const visible = l.toBoolean(3);
        if (visible) {
            sdl3.mouse.show() catch {
                l.raiseErrorStr("failed to show mouse cursor", .{});
                return 0;
            };
        } else {
            sdl3.mouse.hide() catch {
                l.raiseErrorStr("failed to hide mouse cursor", .{});
                return 0;
            };
        }

        return 0;
    }

    l.raiseErrorStr("no property named '%s' exists, you can not assign to it", .{ key.ptr });
    return 0;
}

const InputLib = struct {
    pub fn OnBegin(l: *Lua) i32 {
        if (l.typeOf(1) == .string) {
            const code = parseCodeArg(l, 1) orelse return 0;
            return begin_signal.connect(l, 2, code);
        }

        return begin_signal.connect(l, 1, null);
    }

    pub fn OnEnd(l: *Lua) i32 {
        if (l.typeOf(1) == .string) {
            const code = parseCodeArg(l, 1) orelse return 0;
            return end_signal.connect(l, 2, code);
        }

        return end_signal.connect(l, 1, null);
    }

    pub fn OnChange(l: *Lua) i32 {
        if (l.typeOf(1) == .string) {
            const code = parseCodeArg(l, 1) orelse return 0;
            return change_signal.connect(l, 2, code);
        }

        return change_signal.connect(l, 1, null);
    }

    pub fn GetValue(l: *Lua) i32 {
        const code = parseCodeArg(l, 1) orelse return 0;
        if (down_state.get(code)) |v| {
            switch (v) {
                .scalar => |s| l.pushNumber(s),
                .vec2 => |vec| lua_vec.pushVec2(l, vec)
            }
        } else {
            l.pushNumber(0);
        }

        return 1;
    }

    pub fn IsDown(l: *Lua) i32 {
        const code = parseCodeArg(l, 1) orelse return 0;
        l.pushBoolean(down_state.contains(code));

        return 1;
    }
};

pub fn register(l: *Lua, a: std.mem.Allocator, w: sdl3.video.Window) !void {
    window = w;
    allocator = a;
    down_state = std.AutoHashMap(InputCode, InputValue).init(allocator);
    begin_signal = InputSignal.init(a);
    change_signal = InputSignal.init(a);
    end_signal = InputSignal.init(a);

    const funcs = zlua.fnRegsFromType(InputLib);
    l.newLib(funcs);

    l.newTable();
    l.pushFunction(zlua.wrap(inputIndex));
    l.setField(-2, "__index");
    l.pushFunction(zlua.wrap(inputNewIndex));
    l.setField(-2, "__newindex");
    l.setMetatable(-2);

    l.setGlobal("Input");
}

pub fn deinit(l: *Lua) void {
    begin_signal.deinit(l);
    change_signal.deinit(l);
    end_signal.deinit(l);

    down_state.deinit();
}
