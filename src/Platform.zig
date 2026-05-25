// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl = @import("zsdl2");
const types = @import("Types.zig");

const Vec2_cint = struct { x: c_int, y: c_int };
const Position = union(enum) {
    centered: void,
    xy: Vec2_cint
};

pub const Platform = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Platform {
        // we don't use opengl, but this prevents a weird issue on
        // ProMotion displays where every other renderer.draw() call
        // takes unusually long (~8ms) and halts rendering.
        // boy was that fun to debug!
        try sdl.setHint("SDL_RENDER_DRIVER", "opengl");
        try sdl.init(.{ .video = true });

        return .{
            .allocator = allocator
        };
    }

    pub fn deinit(_: *Platform) void {
        sdl.quit();
    }

    pub fn createWindow(_: *Platform, name: [:0]const u8, pos: Position, size: types.Size2D) !*sdl.Window {
        const p = switch (pos) {
            .centered => Vec2_cint{ .x = sdl.Window.pos_centered, .y = sdl.Window.pos_centered },
            .xy => |vec| vec
        };

        return try sdl.Window.create(
            name,
            p.x, p.y,
            @as(u16, @intCast(size.width)), @as(u16, @intCast(size.height)),
            .{ .resizable = true }
        );
    }
};
