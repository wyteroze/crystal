// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const types = @import("../types.zig");
const Platform = @import("Platform.zig").Platform;
const Window = @import("../Window.zig").Window;
const Renderer = @import("../render/Renderer.zig").Renderer;
const RenderTarget = @import("../render/RenderTarget.zig").RenderTarget;
const WidgetRegistry = @import("WidgetRegistry.zig").WidgetRegistry;
const InputState = @import("../input/Input.zig").InputState;
const Font = @import("../ui/Font.zig").Font;
const Scene = @import("../Scene.zig").Scene;
const Engine = @import("Engine.zig").Engine;

const clear_color = 0xFF_8A_AA_FF;

pub const WindowManager = struct {
    allocator: std.mem.Allocator,
    platform: *Platform,
    windows: std.ArrayList(*Window),
    focused: ?*Window = null,
    engine: *Engine,

    pub fn init(allocator: std.mem.Allocator, platform: *Platform, engine: *Engine) WindowManager {
        return .{
            .allocator = allocator,
            .platform = platform,
            .windows = .empty,
            .engine = engine
        };
    }

    pub fn create(
        self: *WindowManager,
        title: [:0]const u8,
        width: usize,
        height: usize,
        scale: f32,
        want_depth: bool,
        transparent: bool,
        decorated: bool,
        resizable: bool,
    ) !*Window {
        const handle = try self.platform.createWindow(
            title, transparent, decorated, resizable,
            .{ .centered = null }, .{ .centered = null },
            @as(u16, @trunc(@as(f32, @floatFromInt(width))*scale)), // size x
            @as(u16, @trunc(@as(f32, @floatFromInt(height))*scale)) // size y
        );

        const pos = try handle.getPosition();
        const win = try self.allocator.create(Window);
        win.* = .{
            .allocator = self.allocator,
            .handle = handle,
            .id = try handle.getId(),
            .target = try RenderTarget.init(self.allocator, handle, width, height, scale, want_depth, transparent),
            .registry = WidgetRegistry.init(self.allocator),
            .manager = self,
            .input = InputState.init(self.allocator),
            .update_callbacks = .empty,
            .close_callbacks = .empty,
            .focus_callbacks = .empty,
            .focus_lost_callbacks = .empty,
            .UI = .{ .window = win },
            .Input = .{ .window = win },
            .pos = .{ @floatFromInt(pos[0]), @floatFromInt(pos[1]) }
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
                for (w.close_callbacks.items) |cb| {
                    cb.call(.{});
                }

                w.deinit();

                _ = self.windows.swapRemove(i);
                self.allocator.destroy(w);

                return;
            }
        }
    }

    pub fn focus(self: *WindowManager, window: *Window) !void {
        try window.handle.raise();
        self.focused = window;

        for (window.focus_callbacks.items) |cb| {
            cb.call(.{});
        }
    }

    fn focusLost(self: *WindowManager, window: *Window) void {
        if (self.focused == window) self.focused = null;
        for (window.focus_lost_callbacks.items) |cb| {
            cb.call(.{});
        }
    }

    pub fn pumpEvents(self: *WindowManager) void {
        while (sdl3.events.poll()) |e| {
            self.handleEvent(e);
        }
    }

    pub fn handleEvent(self: *WindowManager, event: sdl3.events.Event) void {
        switch (event) {
            .quit => self.engine.quit(.os_request),
            .window_close_requested => |w| if (self.find(w.id)) |win| self.close(win),
            .window_focus_gained => |w| if (self.find(w.id)) |win| self.focus(win) catch {},
            .window_focus_lost => |w| if (self.find(w.id)) |win| self.focusLost(win),
            .mouse_motion, .mouse_button_down, .mouse_button_up, .mouse_wheel => {
                const wid = switch (event) {
                    .mouse_motion => |m| m.window_id,
                    .mouse_button_down, .mouse_button_up => |m| m.window_id,
                    .mouse_wheel => |m| m.window_id,
                    else => unreachable
                };

                if (wid) |id| if (self.find(id)) |w| {
                    // input gets consumed by UI
                    if (!w.registry.handlePointerEvent(event, w.target.scale)) {
                        w.input.dispatch(event);
                    }
                };
            },

            // keyboard and everything else goes to the focused window's input
            else => if (self.focused) |w| w.input.dispatch(event)
        }

        if (self.windows.items.len == 0) self.engine.quit(.no_windows);
    }

    pub fn renderAll(self: *WindowManager, renderer: *Renderer, font: *Font) !void {
        for (self.windows.items) |w| {
            const bg: u32 = if (w.target.transparent) 0x00000000 else clear_color;
            w.target.clear(bg, w.scene != null);

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
