// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const desc = @import("../desc.zig");
const types = @import("../types.zig");

const flags: sdl3.InitFlags = .{ .video = true };

const SdlBackend = @This();

pub fn init(self: SdlBackend) !void {
    _ = self;

    try sdl3.init(flags);
}

pub fn deinit(self: SdlBackend) void {
    _ = self;

    sdl3.quit(flags);
}

pub fn createSurface(self: SdlBackend, d: desc.SurfaceDesc) !types.SurfaceHandle {
    _ = self;

    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_FLAGS, sdl3.c.SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_PROFILE_MASK, sdl3.c.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_MINOR_VERSION, 1);

    const w: sdl3.video.Window = try .init(d.title, @intCast(d.width), @intCast(d.height), .{ .open_gl = true, .resizable = true });
    _ = try sdl3.video.gl.Context.init(w);

    const id = try w.getId();
    return .{ .id = id };
}

pub fn destroySurface(self: SdlBackend, h: types.SurfaceHandle) void {
    _ = self;

    const w = sdl3.video.Window.fromId(@intCast(h.id)) catch unreachable;
    w.deinit();
}

pub fn pollEvent(self: SdlBackend) ?desc.PlatformEvent {
    _ = self;
    const event = sdl3.events.poll() orelse return null;

    return switch (event) {
        .quit => return .quit,
        .window_resized => |e| return .{ .surface_resize = .{ .width = @intCast(e.width), .height = @intCast(e.height) } },
        else => null
    };
}

pub fn getElapsedSeconds(self: SdlBackend) f64 {
    _ = self;
    return @as(f64, @floatCast(sdl3.timer.getNanosecondsSinceInit())) / std.time.ns_per_s;
}

pub fn swapBuffers(self: SdlBackend, h: types.SurfaceHandle) !void {
    _ = self;

    const w: sdl3.video.Window = try .fromId(@intCast(h.id));
    try sdl3.video.gl.swapWindow(w);
}
