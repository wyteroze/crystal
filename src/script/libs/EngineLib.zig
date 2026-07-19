// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const Callback = @import("../shared.zig").Callback;
const Engine = @import("../../engine/Engine.zig").Engine;

pub const EngineLibFrameInfo = struct {
    pub const lua_ref = true;
    pub const hidden = .{ "engine" };
    engine: *Engine = undefined,

    pub fn getFrame(self: EngineLibFrameInfo) usize { return self.engine.frame; }
    pub fn getFPS(self: EngineLibFrameInfo) f32 { return self.engine.fps; }
};

pub const EngineLibProfiler = struct {
    pub const lua_ref = true;
    pub const hidden = .{ "engine" };
    engine: *Engine = undefined,

};

pub const EngineLib = struct {
    pub const name = "Engine";
    pub const hidden = .{ "engine" };
    allocator: std.mem.Allocator,
    engine: *Engine,

    FrameInfo: EngineLibFrameInfo = .{},
    Profiler: EngineLibProfiler = .{},

    pub fn init(allocator: std.mem.Allocator, engine: *Engine) EngineLib {
        return .{
            .allocator = allocator,
            .engine = engine,
            .FrameInfo = .{ .engine = engine },
            .Profiler = .{ .engine = engine },
        };
    }

    pub fn quit(self: *EngineLib) void {
        self.engine.quit(.game_request);
    }

    pub fn OnPostStep(self: *EngineLib, cb: Callback) !void {
        try self.engine.post_step_callbacks.append(self.allocator, cb);
    }
    pub fn OnPreStep(self: *EngineLib, cb: Callback) !void {
        try self.engine.pre_step_callbacks.append(self.allocator, cb);
    }
};
