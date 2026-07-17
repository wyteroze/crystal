// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const sdl3 = @import("sdl3");
const types = @import("types.zig");

pub const Platform = struct {
    pub fn init() !Platform {
        // we don't use opengl but this prevents weird frame
        // stutters on ProMotion displays for some reason?
        try sdl3.init(.{ .video = true, .audio = true });

        return .{};
    }

    pub fn createWindow(
        _: Platform,
        name: [:0]const u8, transparent: bool, decorated: bool,
        pos_x: sdl3.video.Window.Position,
        pos_y: sdl3.video.Window.Position,
        size_x: u16, size_y: u16
    ) !sdl3.video.Window {
        const window = try sdl3.video.Window.init(name, size_x, size_y, .{ .resizable = true, .borderless = !decorated, .transparent = transparent });
        try window.setPosition(pos_x, pos_y);

        return window;
    }

    pub fn deinit(_: Platform) void {
        sdl3.shutdown();
    }
};
