// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const Platform = @import("Platform.zig").Platform;
const Window = @import("Window.zig").Window;
const Renderer = @import("render/Renderer.zig").Renderer;
const RenderTarget = @import("render/RenderTarget.zig").RenderTarget;
const WidgetRegistry = @import("WidgetRegistry.zig").WidgetRegistry;
const InputState = @import("input/Input.zig").InputState;
const Font = @import("ui/Font.zig").Font;
const Scene = @import("Scene.zig").Scene;

const clear_color = 0xFF_8A_AA_FF;

pub const WindowManager = struct {
    allocator: std.mem.Allocator,
    platform: *Platform,
    windows: std.ArrayList(*Window),
    focused: ?*Window = null,

    pub fn init(allocator: std.mem.Allocator, platform: *Platform) WindowManager {
        return .{
            .allocator = allocator,
            .platform = platform,
            .windows = .empty,
        };
    }

    pub fn create(
        self: *WindowManager,
        title: [:0]const u8,
        width: usize,
        height: usize,
        scale: f32,
        want_depth: bool,
        opaque_bg: bool,
        decorated: bool,
    ) !*Window {
        const handle = try self.platform.createWindow(
            title, !opaque_bg, decorated,
            .{ .centered = null }, .{ .centered = null },
            @as(u16, @trunc(@as(f32, @floatFromInt(width))*scale)), // size x
            @as(u16, @trunc(@as(f32, @floatFromInt(height))*scale)) // size y
        );

        const win = try self.allocator.create(Window);
        win.* = .{
            .allocator = self.allocator,
            .handle = handle,
            .id = try handle.getId(),
            .target = try RenderTarget.init(self.allocator, handle, width, height, scale, want_depth, opaque_bg),
            .registry = WidgetRegistry.init(self.allocator),
            .manager = self,
            .input = InputState.init(self.allocator),
            .callbacks = .empty,
            .UI = .{ .window = win },
            .Input = .{ .window = win },
        };

        try self.windows.append(self.allocator, win);
        return win;
    }

    pub fn find(self: *WindowManager, id: sdl3.video.WindowId) ?*Window {
        for (self.windows.items) |w| {
            if (w.id == id) return w;
        }

        return null;
    }

    pub fn close(self: *WindowManager, window: *Window) void {
        for (self.windows.items, 0..) |w, i| {
            if (w == window) {
                if (self.focused == w) self.focused = null;
                w.deinit();

                _ = self.windows.swapRemove(i);
                self.allocator.destroy(w);

                return;
            }
        }
    }

    /// Returns false if the app needs to quit. (aka. no windows left)
    pub fn handleEvent(self: *WindowManager, event: sdl3.events.Event) bool {
        switch (event) {
            .quit => return false,
            .window_close_requested => |w| if (self.find(w.id)) |win| self.close(win),
            .window_focus_gained => |w| self.focused = self.find(w.id),
            .mouse_motion, .mouse_button_down, .mouse_button_up, .mouse_wheel => {
                const wid = switch (event) {
                    .mouse_motion => |m| m.window_id,
                    .mouse_button_down, .mouse_button_up => |m| m.window_id,
                    .mouse_wheel => |m| m.window_id,
                    else => unreachable
                };

                if (wid) |id| if (self.find(id)) |w| {
                    // consumed by UI, not game input
                    if (w.registry.handlePointerEvent(event, w.target.scale)) return true;
                    w.input.dispatch(event);
                };
            },
            // keyboard and everything else goes to the focused window's input
            else => if (self.focused) |w| w.input.dispatch(event)
        }

        if (self.windows.items.len == 0) return false;
        return true;
    }

    pub fn renderAll(self: *WindowManager, renderer: *Renderer, font: *Font) !void {
        for (self.windows.items) |w| {
            // Clear depth only if we're doign 3D
            w.target.clear(clear_color, w.scene != null);
            if (w.scene) |s| {
                const cam = if (w.camera) |obj| obj.data.camera.camera else null;
                try renderer.renderScene(&w.target, s, cam);
            }

            try renderer.drawWidgets(&w.target, font, w.registry.widgets.items);
            try w.target.present();
        }
    }

    pub fn deinit(self: *WindowManager) void {
        for (self.windows.items) |w| {
            w.deinit();
            self.allocator.destroy(w);
        }

        self.windows.deinit(self.allocator);
    }
};
