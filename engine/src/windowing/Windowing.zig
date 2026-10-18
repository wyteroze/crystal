// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const core = @import("../core/core.zig");
const math = core.math;
const Platform = @import("../platform/Platform.zig");
const render = @import("../render/render.zig");
const Ui = @import("../ui/Ui.zig");
pub const Window = @import("Window.zig");
pub const WindowHandle = Window.WindowHandle;
pub const Display = @import("Display.zig");
const types = @import("types.zig");

const Windowing = @This();
allocator: std.mem.Allocator,
dispatcher: core.signal.Dispatcher,
windows: std.AutoHashMap(u64, Window),
displays: std.AutoHashMap(u64, Display),
primary_display: ?Display.DisplayHandle = null,
main_window: ?Window.WindowHandle = null,
evt_connection: core.signal.Connection,
platform: *Platform,
renderer: *render.Renderer,
ui: *Ui,

pub fn init(self: *Windowing, allocator: std.mem.Allocator, platform: *Platform, renderer: *render.Renderer, ui: *Ui) !void {
    self.* = .{
        .allocator = allocator,
        .dispatcher = .init(allocator),
        .windows = .init(allocator),
        .displays = .init(allocator),
        .evt_connection = undefined,
        .platform = platform,
        .renderer = renderer,
        .ui = ui
    };

    self.evt_connection = try platform.platform_event.connect(onPlatformEvent, self);
}

pub fn deinit(self: *Windowing) void {
    self.dispatcher.deinit();
    self.windows.deinit();
    self.displays.deinit();
}

pub fn update(self: *Windowing) void {
    self.dispatcher.flush();
}

pub const CreateWindowOptions = struct {
    title: [:0]const u8 = "",
    parent: ?Window.WindowHandle = null,
    size: math.Vec2 = .zero,
    state: types.WindowState = .normal,
    kind: types.WindowKind = .normal,
    /// Null = primary display
    position: types.WindowPosition = .{},
    visible: bool = true,
    resizable: bool = true,
    always_on_top: bool = false,
    transparent: bool = false,
    borderless: bool = false,
    modal: bool = false,
};

pub fn createWindow(self: *Windowing, options: ?CreateWindowOptions) !Window.WindowHandle {
    const opts: CreateWindowOptions = options orelse .{};
    if (opts.modal and opts.parent == null) {
        std.log.err("A parent must be provided when creating a modal window.", .{});
        return error.ParentRequiredForModalWindow;
    }

    const surface = try self.platform.createSurface(.{ 
        .title = opts.title, 
        .parent = if (opts.parent) |p| (try p.get()).surface else null,
        .width = @trunc(opts.size.x), .height = @trunc(opts.size.y),
        .minimized = opts.state == .minimized,
        .maximized = opts.state == .maximized,
        .fullscreen = opts.state == .fullscreen,
        .utility = opts.kind == .utility,
        .popup = opts.kind == .popup,
        .tooltip = opts.kind == .tooltip,
        .hidden = !opts.visible,
        .resizable = opts.resizable,
        .always_on_top = opts.always_on_top,
        .transparent = opts.transparent,
        .borderless = opts.borderless,
        .modal = opts.modal,
    });

    const pixel = try self.platform.getSurfacePixelSize(surface);
    const logical = try self.platform.getSurfaceLogicalSize(surface);
    const scale = try self.platform.getSurfaceScale(surface);

    try self.renderer.createWindow(surface.id, surface.handle, pixel, scale);

    const entity = try self.ui.world.spawnEntity();
    try self.ui.world.set(entity, self.ui.component_ids.window, Ui.types.Window, .{ .id = surface.id, .scale = scale });
    try self.ui.world.set(entity, self.ui.component_ids.position, math.Vec2, .new(0, 0));
    try self.ui.world.set(entity, self.ui.component_ids.size, Ui.types.SizeMode, .fixed(@floatFromInt(logical[0]), @floatFromInt(logical[1])));
    try self.windows.put(surface.id, .init(self.allocator, &self.dispatcher, self, surface, entity));
    
    return .{ .windowing = self, .id = surface.id };
}

pub fn destroyWindow(self: *Windowing, id: u64) !void {
    const win = self.windows.fetchRemove(id) orelse return error.InvalidWindowId;
    self.renderer.destroyWindow(id) catch |e| {
        std.log.err("Failed to destroy renderer window: {s}", .{ @errorName(e) });
        return;
    };
    self.platform.destroySurface(win.value.surface);
    win.value.entity.destroy();

    if (self.main_window) |mw| if (mw.id == id) {
        // We're closing the main window, so find another window to call main (or set main to nil if there are no other windows)
        // When engine state is more organized in the future, closing the main window should shut down the engine.
        var iter = self.windows.valueIterator();
        self.main_window = if (iter.next()) |w| w.getHandle() else null;
    };
}

pub fn getWindowFromId(self: *Windowing, id: u64) ?*Window {
    return self.windows.getPtr(id);
}

fn onPlatformEvent(self: *Windowing, event: Platform.desc.PlatformEvent) void {
    switch (event) {
        .surface_resize => |evt| {
            const win = self.getWindowFromId(evt.id) orelse return;
            win.updateSize();
            win.resized.fire(.{});
        },
        .surface_closed => |id| {
            const win = self.getWindowFromId(id) orelse return;
            win.closed.fire(.{});
            win.deinit();
        },
        .surface_fullscreened => |id| {
            const win = self.getWindowFromId(id) orelse return;
            win.fullscreened.fire(.{});
        },
        .surface_fullscreen_exited => |id| {
            const win = self.getWindowFromId(id) orelse return;
            win.fullscreen_exited.fire(.{});
        },
        .surface_maximized => |id| {
            const win = self.getWindowFromId(id) orelse return;
            win.maximized.fire(.{});
        },
        .surface_minimized => |id| {
            const win = self.getWindowFromId(id) orelse return;
            win.minimized.fire(.{});
        },
        .surface_restored => |id| {
            const win = self.getWindowFromId(id) orelse return;
            win.restored.fire(.{});
        },

        else => {}
    }
}

const bind = @import("../scripting/bind/bind.zig");
pub const api = bind.module("windowing", .{
    .kind = .{ .singleton = Windowing },
    .members = &.{
        Window.WindowHandle.sub_api,
        bind.func("CreateWindow", Windowing.createWindow),
        bind.readonly("MainWindow", struct {
            fn c(self: *Windowing) ?Window.WindowHandle { return self.main_window; }
        }.c)
    },
});