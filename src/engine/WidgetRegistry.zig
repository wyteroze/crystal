// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const ButtonData = @import("../ui/Widget.zig").ButtonData;
const Widget = @import("../ui/Widget.zig").Widget;
const Vec2 = @import("../script/objects/Vec2.zig").Vec2;

const SCROLL_SPEED: f32 = 24.0;

pub const WidgetRegistry = struct {
    allocator: std.mem.Allocator,
    widgets: std.ArrayList(*Widget),
    hovered: ?*Widget = null,
    pressed: ?*Widget = null,
    last_x: f32 = 0,
    last_y: f32 = 0,
    last_gx: f32 = 0,
    last_gy: f32 = 0,

    pub fn init(allocator: std.mem.Allocator) WidgetRegistry {
        return .{ .allocator = allocator, .widgets = .empty };
    }

    pub fn deinit(self: *WidgetRegistry) void {
        for (self.widgets.items) |w| {
            w.deinit();
            self.allocator.destroy(w);
        }
        self.widgets.deinit(self.allocator);
    }

    pub fn addWidget(self: *WidgetRegistry, widget: *Widget) !void {
        try self.widgets.append(self.allocator, widget);
    }

    pub fn removeWidget(self: *WidgetRegistry, widget: *Widget) void {
        for (self.widgets.items, 0..) |w, i| {
            if (w == widget) {
                if (self.hovered == w) self.hovered = null;
                if (self.pressed == w) self.pressed = null;
                w.deinit();

                _ = self.widgets.swapRemove(i);
                self.allocator.destroy(w);

                return;
            }
        }
    }

    fn pointIn(w: *Widget, cx: f32, cy: f32) bool {
        const r = w.resolved;
        return cx >= r.x and cx < r.x + r.w and cy >= r.y and cy < r.y + r.h;
    }

    fn hitTest(widgets: []*Widget, cx: f32, cy: f32) ?*Widget {
        var i = widgets.len;
        while (i > 0) {
            i -= 1;
            const w = widgets[i];
            if (!w.visible) continue;

            const inside = pointIn(w, cx, cy);
            if (w.clipsChildren() and !inside) continue;

            if (hitTest(w.childSlice(), cx, cy)) |hit| return hit;
            if (inside) return w;
        }
        return null;
    }

    fn asButton(w: *Widget) ?*ButtonData {
        return switch (w.data) { .button => |*b| b, else => null };
    }

    pub fn handlePointerEvent(self: *WidgetRegistry, event: sdl3.events.Event, scale: f32) bool {
        switch (event) {
            .mouse_motion => |m| {
                const cx = m.x / scale;
                const cy = m.y / scale;
                self.last_x = cx;
                self.last_y = cy;
                const hit = hitTest(self.widgets.items, cx, cy);

                if (self.hovered != hit) {
                    if (self.hovered) |h| { if (asButton(h)) |b| b.state = .normal; h.pointerLeave(); }
                    if (hit) |w| w.pointerEnter();
                }
                self.hovered = hit;
                if (hit) |w| if (asButton(w)) |b| { b.state = if (w == self.pressed) .pressed else .hover; };

                if (self.pressed) |w| {
                    const g = sdl3.mouse.getGlobalState();

                    const dx = g[1] - self.last_gx;
                    const dy = g[2] - self.last_gy;
                    self.last_gx = g[1];
                    self.last_gy = g[2];

                    w.pointerDrag(.{ .vec = .{ dx, dy } });
                }

                return hit != null or self.pressed != null;
            },
            .mouse_button_down => |m| {
                if (m.button != .left) return false;

                const cx = m.x / scale;
                const cy = m.y / scale;

                const hit = hitTest(self.widgets.items, cx, cy);
                if (hit) |w| {
                    self.pressed = w;
                    if (asButton(w)) |b| b.state = .pressed;

                    const g = sdl3.mouse.getGlobalState();
                    self.last_gx = g[1];
                    self.last_gy = g[2];

                    w.pointerDown(.{ .vec = .{ cx, cy } });
                }

                return hit != null;
            },
            .mouse_button_up => |m| {
                if (m.button != .left) return false;
                const had_press = self.pressed != null;
                const hit = hitTest(self.widgets.items, m.x / scale, m.y / scale);
                if (self.pressed) |w| {
                    if (hit == w) if (asButton(w)) |b| if (b.on_click) |cb| cb.call(.{});
                    if (asButton(w)) |b| { b.state = if (hit == w) .hover else .normal; }

                    w.pointerUp(.{ .vec = .{ m.x / scale, m.y / scale } });
                }

                self.pressed = null;
                return had_press;
            },
            .mouse_wheel => |m| {
                var target = hitTest(self.widgets.items, self.last_x, self.last_y);
                while (target) |cur| : (target = cur.parent) {
                    if (cur.data == .scroll_container) {
                        cur.addScroll(m.scroll_x * SCROLL_SPEED, -m.scroll_y * SCROLL_SPEED);
                        return true;
                    }
                }

                return false;
            },

            else => return false,
        }
    }
};
