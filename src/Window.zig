// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const types = @import("types.zig");
const Diagnostic = @import("script/shared.zig").Diagnostic;
const WidgetRegistry = @import("engine/WidgetRegistry.zig").WidgetRegistry;
const WindowManager = @import("engine/WindowManager.zig").WindowManager;
const RenderTarget = @import("render/RenderTarget.zig").RenderTarget;
const Vec2 = @import("script/objects/Vec2.zig").Vec2;
const Anchor = @import("ui/Widget.zig").Anchor;
const Widget = @import("ui/Widget.zig").Widget;
const WidgetData = @import("ui/Widget.zig").WidgetData;
const ImageData = @import("ImageData.zig").ImageData;
const Handle = @import("script/reflect/marshal.zig").Handle;
const Color = @import("Color.zig").Color;
const Callback = @import("script/shared.zig").Callback;
const Scene = @import("Scene.zig").Scene;
const Object = @import("object.zig").Object;

const input = @import("input/Input.zig");
const InputState = input.InputState;
const InputCode = input.InputCode;

pub const WindowUI = struct {
    pub const lua_ref = true;
    pub const hidden = .{ "window", "addRoot" };
    window: *Window = undefined,

    fn addRoot(self: *WindowUI, anchor: Anchor, offset: Vec2, size: Vec2, data: WidgetData) !*Widget {
        const window = self.window;
        const widget = try Widget.create(window.allocator, &window.registry, anchor, offset.vec, size.vec, data);
        errdefer { widget.deinit(); window.allocator.destroy(widget); }

        try window.registry.addWidget(widget);
        return widget;
    }

    pub fn Panel(self: *WindowUI, anchor: Anchor, offset: Vec2, size: Vec2) !Handle(Widget) {
        const w = try self.addRoot(anchor, offset, size, .{ .panel = .{ .bg = Color.fromARGB(255, 255, 255, 255) } });
        return .{ .ptr = w };
    }

    pub fn Label(self: *WindowUI, anchor: Anchor, offset: Vec2, text: []const u8) !Handle(Widget) {
        const owned = try self.window.allocator.dupe(u8, text);
        errdefer self.window.allocator.free(owned);

        const w = try self.addRoot(anchor, offset, Vec2{ .vec = .{ 0, 0 } }, .{ .label = .{ .content = .{ .text = owned, .color = Color.fromARGB(255, 255, 255, 255) } } });
        return .{ .ptr = w };
    }

    pub fn Button(self: *WindowUI, anchor: Anchor, offset: Vec2, size: Vec2, text: []const u8) !Handle(Widget) {
        const owned = try self.window.allocator.dupe(u8, text);
        errdefer self.window.allocator.free(owned);

        const w = try self.addRoot(anchor, offset, size, .{ .button = .{
            .bg = Color.fromARGB(255, 128, 128, 128),
            .content = .{ .text = owned, .color = Color.fromARGB(255, 255, 255, 255) },
        } });

        return .{ .ptr = w };
    }

    pub fn Canvas(self: *WindowUI, anchor: Anchor, offset: Vec2, size: Vec2) !Handle(Widget) {
        const w = try self.addRoot(anchor, offset, size, .{ .canvas = .{} });
        return .{ .ptr = w };
    }

    pub fn Image(self: *WindowUI, anchor: Anchor, offset: Vec2, size: Vec2, image: Handle(ImageData)) !Handle(Widget) {
        const w = try self.addRoot(anchor, offset, size, .{ .image = .{ .image = image.ptr } });
        return .{ .ptr = w };
    }

    pub fn Container(self: *WindowUI, anchor: Anchor, offset: Vec2, size: Vec2) !Handle(Widget) {
        const w = try self.addRoot(anchor, offset, size, .{ .container = .{} });
        return .{ .ptr = w };
    }

    pub fn ScrollContainer(self: *WindowUI, anchor: Anchor, offset: Vec2, size: Vec2) !Handle(Widget) {
        const w = try self.addRoot(anchor, offset, size, .{ .scroll_container = .{} });
        return .{ .ptr = w };
    }
};

pub const WindowInput = struct {
    pub const lua_ref = true;
    pub const hidden = .{ "window", "bind" };
    window: *Window = undefined,

    fn bind(self: *WindowInput, phase: anytype, code: InputCode, cb: Callback) !void {
        const state = &self.window.input;
        try state.bindings.append(state.allocator, .{ .phase = phase, .code = code, .cb = cb });
    }
    pub fn OnBegin(self: *WindowInput, code: InputCode, cb: Callback) !void { try self.bind(.begin, code, cb); }
    pub fn OnEnd(self: *WindowInput, code: InputCode, cb: Callback) !void { try self.bind(.end, code, cb); }
    pub fn OnChange(self: *WindowInput, code: InputCode, cb: Callback) !void { try self.bind(.change, code, cb); }

    pub fn IsDown(self: *WindowInput, code: InputCode) bool { return self.window.input.down.contains(code); }
    pub fn GetValue(self: *WindowInput, code: InputCode) f32 {
        return if (self.window.input.down.get(code)) |v| switch (v) { .scalar => |s| s, .vec2 => 0 } else 0;
    }

    pub fn setMouseVisible(_: *WindowInput, visible: bool) !void {
        if (visible) try sdl3.mouse.show() else try sdl3.mouse.hide();
    }
    pub fn getMouseVisible(_: WindowInput) bool {
        return sdl3.mouse.visible();
    }

    pub fn setMouseLocked(self: *WindowInput, locked: bool) !void {
        try sdl3.mouse.setWindowRelativeMode(self.window.handle, locked);
    }
    pub fn getMouseLocked(self: WindowInput) bool {
        return sdl3.mouse.getWindowRelativeMode(self.window.handle);
    }
};

pub const Window = struct {
    pub const lua_ref = true;
    pub const lua_name = "WindowInstance";
    pub const hidden = .{
        "handle", "id", "target", "registry",
        "manager", "input", "update", "scene", "camera",
        "focus_callbacks", "close_callbacks", "focus_lost_callbacks"
    };
    diagnostic: Diagnostic = .{},
    allocator: std.mem.Allocator,

    handle: sdl3.video.Window,
    id: sdl3.video.WindowId,
    target: RenderTarget,
    registry: WidgetRegistry,
    manager: *WindowManager,
    input: InputState,

    UI: WindowUI = .{},
    Input: WindowInput = .{},

    scene: ?*Scene = null,
    camera: ?*Object = null,
    update_callbacks: std.ArrayList(Callback),
    close_callbacks: std.ArrayList(Callback),
    focus_callbacks: std.ArrayList(Callback),
    focus_lost_callbacks: std.ArrayList(Callback),

    // Ugly fix, but mouse movement is a float and window position
    // is an int, so there's some loss between the two. we store our
    // own internal position which has no loss, and set the real
    // window position to it when needed.
    pos: types.Vec2,

    pub fn getTitle(self: Window) ?[:0]const u8 { return self.handle.getTitle(); }
    pub fn setTitle(self: *Window, title: [:0]const u8) !void { try self.handle.setTitle(title); }

    pub fn getPosition(self: Window) !Vec2 {
        const realPos = try self.handle.getPosition();
        const rx = @as(isize, @intFromFloat(@round(self.pos[0])));
        const ry = @as(isize, @intFromFloat(@round(self.pos[1])));

        // sdl disagrees with our internal window position, resync it
        if (realPos[0] != rx or realPos[1] != ry) {
            const mut_self = self.manager.find(self.id) orelse unreachable;
            mut_self.pos = .{ @floatFromInt(realPos[0]), @floatFromInt(realPos[1]) };
        }

        return .{ .vec = self.pos };
    }
    pub fn setPosition(self: *Window, v: Vec2) !void {
        self.pos = v.vec;

        const px = @as(isize, @intFromFloat(v.vec[0]));
        const py = @as(isize, @intFromFloat(v.vec[1]));

        try self.handle.setPosition(.{ .absolute = px }, .{ .absolute = py });
    }

    pub fn getScene(self: Window) ?Handle(Scene) {
        return .{ .ptr = self.scene orelse return null };
    }
    pub fn setScene(self: *Window, scene: ?Handle(Scene)) void {
        self.scene = if (scene) |s| s.ptr else null;
    }

    pub fn getCamera(self: Window) ?Handle(Object) {
        return .{ .ptr = self.camera orelse return null };
    }

    pub fn setCamera(self: *Window, camera: Handle(Object)) !void {
        switch (camera.ptr.data) {
            .camera => self.camera = camera.ptr,
            else => |d| { self.diagnostic.set("expected camera, got {s}", .{d.luaName()}); return error.ExpectedCamera; },
        }
    }

    pub fn update(self: *Window, dt: f32) void {
        for (self.update_callbacks.items) |cb| {
            cb.call(.{ dt });
        }
    }

    pub fn Close(self: *Window) void {
        self.manager.close(self);
    }

    pub fn Minimize(self: *Window) !void {
        try self.handle.minimize();
    }

    pub fn Maximize(self: *Window) !void {
        try self.handle.maximize();
    }

    pub fn Focus(self: *Window) !void {
        try self.manager.focus(self);
    }

    pub fn OnUpdate(self: *Window, cb: Callback) !void {
        try self.update_callbacks.append(self.allocator, cb);
    }

    pub fn OnClose(self: *Window, cb: Callback) !void {
        try self.close_callbacks.append(self.allocator, cb);
    }

    pub fn OnFocus(self: *Window, cb: Callback) !void {
        try self.focus_callbacks.append(self.allocator, cb);
    }

    pub fn OnFocusLost(self: *Window, cb: Callback) !void {
        try self.focus_lost_callbacks.append(self.allocator, cb);
    }

    pub fn deinit(self: *Window) void {
        for (self.update_callbacks.items) |cb| cb.deinit();
        for (self.close_callbacks.items) |cb| cb.deinit();
        for (self.focus_callbacks.items) |cb| cb.deinit();
        for (self.focus_lost_callbacks.items) |cb| cb.deinit();
        self.update_callbacks.deinit(self.allocator);
        self.close_callbacks.deinit(self.allocator);
        self.focus_callbacks.deinit(self.allocator);
        self.focus_lost_callbacks.deinit(self.allocator);

        self.input.deinit();
        self.registry.deinit();
        self.target.deinit();
        self.handle.deinit();
    }
};
