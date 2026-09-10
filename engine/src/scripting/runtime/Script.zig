// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const ecs = @import("../../ecs/ecs.zig");
const linker = @import("../linker/linker.zig");
const types = @import("../../assets/types.zig");
const Lua = zlua.Lua;

const Script = @This();
source: types.ScriptSource,
state: *Lua,
ref: i32,
instance_ref: ?i32 = null,

pub fn init(state: *Lua, source: types.ScriptSource) !Script {
    // sentinel terminate the source data
    const data_z = try state.allocator().dupeSentinel(u8, source.data, 0);
    defer state.allocator().free(data_z);

    // load and run sentinel terminated string
    try state.loadString(data_z);
    state.protectedCall(.{ .args = 0, .results = 1 }) catch {};

    const ref = state.ref(zlua.registry_index);
    return .{
        .source = source,
        .state = state,
        .ref = ref
    };
}

pub fn callFunction(self: *const Script, name: [:0]const u8, comptime ResultTypes: []const type, args: anytype) !@Tuple(ResultTypes) {
    const top = self.state.getTop();
    defer self.state.setTop(top);

    const handler_idx = self.pushMsgHandler();
    _ = self.state.getGlobal(name) catch return error.UnknownFunction;

    inline for (args) |a| {
        linker.util.pushVal(self.state, @TypeOf(a), a);
    }

    self.state.protectedCall(.{ .args = args.len, .results = ResultTypes.len, .msg_handler = handler_idx }) catch self.luaErr();

    var results: @Tuple(ResultTypes) = undefined;
    inline for (ResultTypes, 0..) |R, i| {
        const idx = top + 1 + 1 + @as(i32, @intCast(i));
        results[i] = try linker.util.parseVal(self.state, R, idx);
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
        linker.util.pushVal(self.state, @TypeOf(a), a);
    }

    self.state.protectedCall(.{ .args = args.len+1, .results = ResultTypes.len, .msg_handler = handler_idx }) catch self.luaErr();

    var results: @Tuple(ResultTypes) = undefined;
    inline for (ResultTypes, 0..) |R, i| {
        const idx = top + 1 + 1 + @as(i32, @intCast(i));
        results[i] = try linker.util.parseVal(self.state, R, idx);
    }

    return results;
}

/// Param is the first value passed to the .new function.
pub fn instantiate(self: *Script, param: anytype) !void {
    const top = self.state.getTop();
    defer self.state.setTop(top);

    const handler_idx = self.pushMsgHandler();
    _ = self.state.getIndexRaw(zlua.registry_index, self.ref);
    _ = self.state.getField(-1, "new");
    self.state.remove(-2);

    linker.util.pushVal(self.state, @TypeOf(param), param);
    self.state.protectedCall(.{ .args = 1, .results = 1, .msg_handler = handler_idx }) catch self.luaErr(); 

    self.instance_ref = self.state.ref(zlua.registry_index);
}

pub fn deinit(self: *const Script) void {
    self.state.unref(zlua.registry_index, self.ref);
}

fn pushMsgHandler(self: *const Script) i32 {
    self.state.pushFunction(zlua.wrap(struct {
        fn c(l: *Lua) i32 {
            const msg = l.toString(-1) catch "unknown error";
            l.traceback(l, msg, 1);
            return 1;
        }
    }.c));
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
