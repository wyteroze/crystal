// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Window = @import("../../Window.zig").Window;
const WindowManager = @import("../../WindowManager.zig").WindowManager;
const Handle = @import("../reflect/marshal.zig").Handle;

pub const WindowLib = struct {
    pub const name = "Window";
    pub const hidden = .{ "manager" };
    manager: *WindowManager,

    pub fn init(manager: *WindowManager) WindowLib {
        return .{ .manager = manager };
    }

    pub fn new(self: *WindowLib, title: [:0]const u8, width: usize, height: usize, scale: ?f32) !Handle(Window) {
        const win = try self.manager.create(title, width, height, scale orelse 1.0, true, true);
        return .{ .ptr = win };
    }
};
