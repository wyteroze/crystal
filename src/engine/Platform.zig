// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const sdl3 = @import("sdl3");
const types = @import("../types.zig");

pub const Platform = struct {
    pub fn init() !Platform {
        // we don't use opengl but this prevents weird frame
        // stutters on ProMotion displays for some reason?
        try sdl3.init(.{ .video = true, .audio = true });

        return .{};
    }

    pub fn createWindow(
        _: Platform,
        name: [:0]const u8, transparent: bool,
        decorated: bool, resizable: bool,
        pos_x: sdl3.video.Window.Position,
        pos_y: sdl3.video.Window.Position,
        size_x: u16, size_y: u16
    ) !sdl3.video.Window {
        // We need high pixel density because the OS upscales and makes pixels blurry otherwise
        const window = try sdl3.video.Window.init(name, size_x, size_y, .{
            .resizable = resizable,
            .borderless = !decorated,
            .transparent = transparent,
            .high_pixel_density = true,
        });
        try window.setPosition(pos_x, pos_y);

        return window;
    }

    pub fn deinit(_: Platform) void {
        sdl3.shutdown();
    }
};
