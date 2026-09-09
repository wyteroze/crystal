// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const builtin = @import("builtin");
const objc = @import("objc");
const sdl3 = @import("sdl3");
const desc = @import("../desc.zig");
const types = @import("../types.zig");

const flags: sdl3.InitFlags = .{ .video = true };

const SdlBackend = @This();

pub fn init(_: SdlBackend) void {
    sdl3.init(flags) catch {
        std.log.err("Failed to init sdl3: {s}", .{ sdl3.errors.get() orelse "no error message" });
    };
}

pub fn deinit(_: SdlBackend) void {

    sdl3.quit(flags);
}

pub fn createSurface(_: SdlBackend, d: desc.SurfaceDesc) !types.SurfaceHandle {
    const w: sdl3.video.Window = try .init(
        d.title, 
        @intCast(d.width), 
        @intCast(d.height), 
        .{
            .metal = true, 
            .resizable = true 
        }
    );

    const props = try w.getProperties();
    const handle = if (props.android_window) |win| win.value
        else if (props.ui_kit_window) |win| win.value
        else if (props.cocoa_window != null) sdl3.c.SDL_Metal_CreateView(w.value)
        else if (props.vivante_window) |win| win.value
        else if (props.win32_hwnd) |win| win.value
        else if (props.wayland_viewport) |win| win.value
        else if (props.x11_display) |win| win.value
        else unreachable;
    
    return .{ .id = try w.getId(), .handle = handle };
}

pub fn getSurfacePixelSize(_: SdlBackend, h: types.SurfaceHandle) [2]u32 {
    const w = sdl3.video.Window.fromId(@intCast(h.id)) catch unreachable;
    const size = w.getSizeInPixels() catch unreachable;

    return .{ @intCast(size[0]), @intCast(size[1]) };
}

pub fn destroySurface(_: SdlBackend, h: types.SurfaceHandle) void {
    const w = sdl3.video.Window.fromId(@intCast(h.id)) catch unreachable;
    w.deinit();
}

pub fn pollEvent(_: SdlBackend) ?desc.PlatformEvent {
    const event = sdl3.events.poll() orelse return null;

    return switch (event) {
        .quit => return .quit,
        .window_resized => |e| return .{ .surface_resize = .{ .width = @intCast(e.width), .height = @intCast(e.height) } },
        else => null,
    };
}
