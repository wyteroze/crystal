// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const ecs = @import("../../ecs/ecs.zig");
const bind = @import("../bind/bind.zig");
const types = @import("../../assets/types.zig");
const Lua = zlua.Lua;

const Script = @This();
source: types.ScriptSource,
main: *Lua,
state: *Lua,
thread_ref: i32,
ref: i32,
instance_ref: ?i32 = null,
binder: bind.Binder(bind.api),

pub fn init(main: *Lua, state: *Lua, thread_ref: i32, source: types.ScriptSource, binder: bind.Binder(bind.api)) !Script {
    // compile and run script
    const bytecode = switch (source.type) {
        .text => try zlua.compile(state.allocator(), source.data, .{}),
        .bytecode => source.data
    };
    defer if (source.type == .text) state.allocator().free(bytecode);


    if (bytecode.len > 0 and bytecode[0] == 0) {
        std.log.err("Script compilation failed: {s}", .{ bytecode[1..] });
        return error.ScriptCompilationFailed;
    }

    try state.loadBytecode("Script", bytecode);
    state.protectedCall(.{ .args = 0, .results = 1 }) catch {
        std.log.err("Failed to initialize script: {s}", .{ state.toString(-1) catch unreachable });
        state.pop(1);

        return error.ScriptInitFailed;
    };

    const ref = state.ref(-1);
    state.pop(1);

    return .{
        .source = source,
        .main = main,
        .state = state,
        .thread_ref = thread_ref,
        .ref = ref,
        .binder = binder
    };
}

pub fn callFunction(self: *const Script, name: [:0]const u8, comptime ResultTypes: []const type, args: anytype) !@Tuple(ResultTypes) {
    const top = self.state.getTop();
    defer self.state.setTop(top);

    const handler_idx = self.pushMsgHandler();
    _ = self.state.getGlobal(name) catch return error.UnknownFunction;

    inline for (args) |a| {
        self.binder.pushValue(self.state, a);
    }

    self.state.protectedCall(.{ .args = args.len, .results = ResultTypes.len, .msg_handler = handler_idx }) catch self.luaErr();

    var results: @Tuple(ResultTypes) = undefined;
    inline for (ResultTypes, 0..) |R, i| {
        const idx = top + 1 + 1 + @as(i32, @intCast(i));
        results[i] = self.binder.parseValue(self.state, R, idx);
    }

    return results;
}

/// This is only callable once `instantiate` is called. The first parameter of the function is the
/// returned value of the instantiate function.
pub fn callMethod(self: *const Script, name: [:0]const u8, comptime ResultTypes: []const type, args: anytype) !@Tuple(ResultTypes) {
    const top = self.state.getTop();
    defer self.state.setTop(top);

    const handler_idx = self.pushMsgHandler();
    _ = self.state.getIndexRaw(zlua.registry_index, self.instance_ref.?);
    _ = self.state.getField(-1, name);
    if (!self.state.isFunction(-1)) return error.UnknownFunction;

    self.state.pushValue(-2);
    self.state.remove(-3);

    inline for (args) |a| {
        self.binder.pushValue(self.state, a);
    }

    self.state.protectedCall(.{ .args = args.len+1, .results = ResultTypes.len, .msg_handler = handler_idx }) catch {
        self.luaErr();
        return error.MethodCallFailed;
    };

    var results: @Tuple(ResultTypes) = undefined;
    inline for (ResultTypes, 0..) |R, i| {
        const idx = handler_idx + 1 + @as(i32, @intCast(i));
        results[i] = self.binder.parseValue(self.state, R, idx);
    }

    return results;
}

/// Param is the first value passed to the .new function.
pub fn instantiate(self: *Script, param: anytype) !void {
    if (self.ref == 0) return error.NoInstanceTable;
    const top = self.state.getTop();
    defer self.state.setTop(top);

    const handler_idx = self.pushMsgHandler();
    _ = self.state.getIndexRaw(zlua.registry_index, self.ref);
    _ = self.state.getField(-1, "new");
    self.state.remove(-2);

    self.binder.pushValue(self.state, param);
    self.state.protectedCall(.{ .args = 1, .results = 1, .msg_handler = handler_idx }) catch {
        self.luaErr();
        return error.InstantiateFailed;
    };

    self.instance_ref = self.state.ref(-1);
}

pub fn deinit(self: *const Script) void {
    if (self.instance_ref) |r| self.state.unref(r);
    self.state.unref(self.ref);
    self.main.unref(self.thread_ref);
}

fn pushMsgHandler(self: *const Script) i32 {
    self.state.pushFunction(zlua.wrap(struct {
        fn c(l: *Lua) i32 {
            const msg = l.toString(-1) catch "unknown error";
            l.traceback(l, msg, 1);
            return 1;
        }
    }.c), "msgHandler");

    return self.state.getTop();
}

fn luaErr(self: *const Script) void {
    const msg = self.state.toString(-1) catch "unknown error";
    var formatted = false;

    // find the ": "
    if (std.mem.indexOf(u8, msg, ": ")) |msg_sep| {
        // search backwards in order to find the separator of file and line
        if (std.mem.findScalarLast(u8, msg[0..msg_sep], ':')) |line_sep| {
            const line = msg[line_sep+1 .. msg_sep];
            const err_msg = msg[msg_sep + 2 ..]; // skip ":"

            // todo: change second format arg to script path, I removed it without
            // knowing this needed it and I'm too lazy to add it back
            std.log.err("{s}\n         in {s} (line {s})", .{ err_msg, "script", line });
            formatted = true;
        }
    }

    if (!formatted) {
        std.log.err("{s}", .{ msg });
    }

    self.state.pop(1);
}
