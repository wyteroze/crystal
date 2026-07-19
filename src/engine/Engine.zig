// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Callback = @import("../script/shared.zig").Callback;

pub const CloseReason = enum {
    os_request,
    game_request,
    no_windows
};

pub const Engine = struct {
    io: std.Io,
    allocator: std.mem.Allocator,

    fps: f32 = 0,
    frame: usize = 0,
    running: bool = true,
    close_reason: ?CloseReason = null,
    pre_step_callbacks: std.ArrayList(Callback),
    post_step_callbacks: std.ArrayList(Callback),

    pub fn init(self: *Engine, allocator: std.mem.Allocator, io: std.Io) !void {
        self.* = .{
            .io = io,
            .allocator = allocator,
            .pre_step_callbacks = .empty,
            .post_step_callbacks =.empty
        };
    }

    pub fn deinit(self: *Engine) void {
        for (self.pre_step_callbacks.items) |cb| cb.deinit();
        for (self.post_step_callbacks.items) |cb| cb.deinit();
        self.pre_step_callbacks.deinit(self.allocator);
        self.post_step_callbacks.deinit(self.allocator);
    }

    pub fn quit(self: *Engine, reason: CloseReason) void {
        self.running = false;
        self.close_reason = reason;
    }

    pub fn preStep(self: *Engine) void {
        for (self.post_step_callbacks.items) |cb| {
            cb.call(.{});
        }
    }

    pub fn postStep(self: *Engine) void {
        for (self.post_step_callbacks.items) |cb| {
            cb.call(.{});
        }
    }
};
