// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const signal = @import("../core/signal.zig");
const math = @import("../core/math/math.zig");
const bind = @import("../scripting/bind/bind.zig");
const Platform = @import("../platform/Platform.zig");
const Windowing = @import("Windowing.zig");
const Ui = @import("../ui/Ui.zig");

pub const WindowEvent = signal.Signal(.{});

const Window = @This();
windowing: *Windowing,
surface: Platform.types.SurfaceHandle,
entity: ecs.Entity,

closed: WindowEvent,
resized: WindowEvent,
fullscreened: WindowEvent,
fullscreen_exited: WindowEvent,
maximized: WindowEvent,
minimized: WindowEvent,
restored: WindowEvent,

pub fn init(allocator: std.mem.Allocator, dispatcher: *signal.Dispatcher, windowing: *Windowing, surface: Platform.types.SurfaceHandle, entity: ecs.Entity) Window {
    return .{
        .windowing = windowing,
        .surface = surface,
        .entity = entity,
        
        .closed = .init(allocator, dispatcher),
        .resized = .init(allocator, dispatcher),
        .fullscreened = .init(allocator, dispatcher),
        .fullscreen_exited = .init(allocator, dispatcher),
        .maximized = .init(allocator, dispatcher),
        .minimized = .init(allocator, dispatcher),
        .restored = .init(allocator, dispatcher)
    };
}

pub fn deinit(self: *Window) void {
    self.closed.deinit();
    self.resized.deinit();
    self.fullscreened.deinit();
    self.fullscreen_exited.deinit();
    self.maximized.deinit();
    self.minimized.deinit();
    self.restored.deinit();

    self.windowing.destroyWindow(self.surface.id) catch |e| {
        std.log.err("Failed to destroy window: {s}", .{ @errorName(e) });
    };
}

pub fn updateSize(self: *Window) void {
    const platform = self.windowing.platform;
    const renderer = self.windowing.renderer;
    const ui = self.windowing.ui;

    const pixel = platform.getSurfacePixelSize(self.surface) catch return;
    const logical = platform.getSurfaceLogicalSize(self.surface) catch return;
    const scale = platform.getSurfaceScale(self.surface) catch return;

    renderer.resizeWindow(self.surface.id, pixel, scale) catch |e| std.log.err("Failed to resized window: {s}", .{ @errorName(e) });

    if (ui.world.getComponent(self.entity, ui.component_ids.window, Ui.types.Window)) |w| w.scale = scale;
    ui.world.set(self.entity, ui.component_ids.size, Ui.types.SizeMode,
        .fixed(@floatFromInt(logical[0]), @floatFromInt(logical[1]))) catch {};
}

pub fn getId(self: *Window) usize {
    return self.surface.id;
}

pub fn getSize(self: *Window) !math.Vec2 {
    const sz = try self.windowing.platform.getSurfaceLogicalSize(self.surface);
    return .new(@floatFromInt(sz[0]), @floatFromInt(sz[1]));
}

pub fn setSize(self: *Window, size: math.Vec2) !void {
    const sz: math.Vec2 = .new(@max(1, size.x), @max(1, size.y));
    try self.windowing.platform.setSurfaceSize(self.surface, .{ @trunc(sz.x), @trunc(sz.y) });
}

pub fn enterFullscreen(self: *Window) !void {
    try self.windowing.platform.setSurfaceFullscreen(self.surface, true);
}

pub fn exitFullscreen(self: *Window) !void {
    try self.windowing.platform.setSurfaceFullscreen(self.surface, false);
}

pub fn maximize(self: *Window) !void {
    try self.windowing.platform.maximizeSurface(self.surface);
}

pub fn minimize(self: *Window) !void {
    try self.windowing.platform.minimizeSurface(self.surface);
}

pub fn restore(self: *Window) !void {
    try self.windowing.platform.restoreSurface(self.surface);
}

pub fn isFocused(self: *Window) !bool {
    return self.windowing.platform.getSurfaceFocused(self.surface);
}

pub fn focus(self: *Window) !void {
    try self.windowing.platform.focusSurface(self.surface);
}

pub fn getHandle(self: *Window) WindowHandle {
    return .{ .windowing = self.windowing, .id = self.getId() };
}

pub const WindowHandle = struct {
    windowing: *Windowing,
    id: u64,

    pub fn isAlive(self: WindowHandle) bool {
        return self.windowing.getWindowFromId(self.id) != null;
    }

    pub fn get(self: WindowHandle) !*Window {
        return self.windowing.getWindowFromId(self.id) orelse error.InvalidHandle;
    }

    pub fn getElement(self: WindowHandle) !Ui.Element {
        const w = try self.get();
        return .{ .entity = w.entity };
    }

    pub fn enterFullscreen(self: WindowHandle) !void {
        try (try self.get()).enterFullscreen();
    }

    pub fn exitFullscreen(self: WindowHandle) !void {
        try (try self.get()).exitFullscreen();
    }

    pub fn maximize(self: WindowHandle) !void {
        try (try self.get()).maximize();
    }

    pub fn minimize(self: WindowHandle) !void {
        try (try self.get()).minimize();
    }

    pub fn restore(self: WindowHandle) !void {
        try (try self.get()).restore();
    }

    pub fn destroy(self: WindowHandle) !void {
        (try self.get()).deinit();
    }

    pub fn getSize(self: WindowHandle) !math.Vec2 {
        return (try self.get()).getSize();
    }

    pub fn setSize(self: WindowHandle, size: math.Vec2) !void {
        return (try self.get()).setSize(size);
    }

    pub fn isFocused(self: WindowHandle) !bool {
        return (try self.get()).isFocused();
    }

    pub fn focus(self: WindowHandle) !void {
        try (try self.get()).focus();
    }

    pub const sub_api = bind.handle(WindowHandle, .{
        .name = "Window",
        .alive = bind.func("isAlive", WindowHandle.isAlive),
        .methods = &.{
            bind.func("EnterFullscreen", WindowHandle.enterFullscreen),
            bind.func("ExitFullscreen", WindowHandle.exitFullscreen),
            bind.func("Maximize", WindowHandle.maximize),
            bind.func("Minimize", WindowHandle.minimize),
            bind.func("Restore", WindowHandle.restore),
            bind.func("Destroy", WindowHandle.destroy),
            bind.func("Focus", WindowHandle.focus)
        },
        .props = &.{
            bind.signal("Closed", struct { 
                fn c(self: WindowHandle) !*WindowEvent { return &(try self.get()).closed; } }
            .c),
            bind.signal("Resized", struct { 
                fn c(self: WindowHandle) !*WindowEvent { return &(try self.get()).resized; } }
            .c),
            bind.signal("Fullscreened", struct { 
                fn c(self: WindowHandle) !*WindowEvent { return &(try self.get()).fullscreened; } }
            .c),
            bind.signal("FullscreenExited", struct { 
                fn c(self: WindowHandle) !*WindowEvent { return &(try self.get()).fullscreen_exited; } }
            .c),
            bind.signal("Maximized", struct { 
                fn c(self: WindowHandle) !*WindowEvent { return &(try self.get()).maximized; } }
            .c),
            bind.signal("Minimized", struct { 
                fn c(self: WindowHandle) !*WindowEvent { return &(try self.get()).minimized; } }
            .c),
            bind.signal("Restored", struct { 
                fn c(self: WindowHandle) !*WindowEvent { return &(try self.get()).restored; } }
            .c),
            bind.readonly("Element", WindowHandle.getElement),
            bind.readonly("Focused", WindowHandle.isFocused),
            bind.prop("Size", WindowHandle.getSize, WindowHandle.setSize),
            // TODO: Make window positioning ergonomic and make the api nice to use
            //bind.prop("Position", WindowHandle.getPosition, WindowHandle.setPosition),
        },
        .ops = .{ .eq = .{ .member = bind.func("eq", struct { fn eq(self: WindowHandle, other: WindowHandle) bool { return self.id == other.id; } }.eq) } }
    });
};