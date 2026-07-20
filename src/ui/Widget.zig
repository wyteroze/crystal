// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Color = @import("../Color.zig").Color;
const Font = @import("Font.zig").Font;
const TextSize = @import("Font.zig").TextSize;
const types = @import("../types.zig");
const Vec2 = @import("../script/objects/Vec2.zig").Vec2;
const Callback = @import("../script/shared.zig").Callback;
const marshal = @import("../script/reflect/marshal.zig");
const Handle = marshal.Handle;
const Diagnostic = @import("../script/shared.zig").Diagnostic;
const Painter = @import("../render/Painter.zig").Painter;
const UIPainter = @import("../render/UIPainter.zig");
const WidgetRegistry = @import("../engine/WidgetRegistry.zig").WidgetRegistry;
const ImageData = @import("../ImageData.zig").ImageData;

const WidgetList = std.ArrayList(*Widget);

const TextContent = struct {
    text: []const u8 = "",
    color: Color,
    font: ?*Font = null,
    font_scale: u32 = 1,
    // This gets cached every time `font.measure()` is called
    measured: ?types.Vec2 = null,
    // The font that `measured` was computed with
    measured_with: ?*Font = null,
    // The font scale that `measured` was comptued with.
    measured_scale: u32 = 1,
};

pub const ButtonState = enum { normal, hover, pressed };

pub const PanelData  = struct {
    bg: Color,
    border_color: ?Color = null,
    border_size: i32 = 1,
    border_top: bool = true,
    border_bottom: bool = true,
    border_left: bool = true,
    border_right: bool = true,
};
pub const LabelData  = struct { content: TextContent };
pub const ButtonData = struct {
    state: ButtonState = .normal,
    bg: Color,
    border_color: ?Color = null,
    border_size: i32 = 1,
    border_top: bool = true,
    border_bottom: bool = true,
    border_left: bool = true,
    border_right: bool = true,
    content: TextContent,
    on_click: ?Callback = null,
};
pub const CanvasData = struct { on_paint: ?Callback = null };
pub const ImageWidgetData = struct { image: *ImageData, tint: ?Color = null };

pub const ContainerData = struct {
    children: WidgetList = .empty,
    layout: Layout = .absolute,
    alignment: Align = .Start,
    clip: bool = false,
    bg: ?Color = null,
    border_color: ?Color = null,
    border_size: i32 = 1,
    border_top: bool = true,
    border_bottom: bool = true,
    border_left: bool = true,
    border_right: bool = true,
};
pub const ScrollData = struct {
    children: WidgetList = .empty,
    layout: Layout = .absolute,
    alignment: Align = .Start,
    clip: bool = true,
    bg: ?Color = null,
    border_color: ?Color = null,
    border_size: i32 = 1,
    border_top: bool = true,
    border_bottom: bool = true,
    border_left: bool = true,
    border_right: bool = true,
    scroll: types.Vec2 = .{ 0, 0 },
    content_size: types.Vec2 = .{ 0, 0 }, // extents of children
};

pub const AbsRect = struct { x: f32, y: f32, w: f32, h: f32 };

pub const Anchor = enum {
    TopLeft, Top, TopRight,
    Left, Center, Right,
    BottomLeft, Bottom, BottomRight,

    pub fn factor(self: Anchor) types.Vec2 {
        return switch (self) {
            .TopLeft => .{ 0, 0 },   .Top => .{ 0.5, 0 },     .TopRight => .{ 1, 0 },
            .Left    => .{ 0, 0.5 }, .Center => .{ 0.5, 0.5 }, .Right    => .{ 1, 0.5 },
            .BottomLeft => .{ 0, 1 },.Bottom => .{ 0.5, 1 },   .BottomRight => .{ 1, 1 },
        };
    }
};

pub const Layout = union(enum) {
    absolute: void,
    stack_vertical: f32,
    stack_horizontal: f32,
};

pub const Align = enum { Start, Center, End };

fn alignOffset(a: Align, container: f32, total: f32) f32 {
    return switch (a) {
        .Start => 0,
        .Center => (container - total) / 2,
        .End => container - total,
    };
}

pub const WidgetKind = enum { panel, label, button, canvas, image, container, scroll_container };

pub const WidgetData = union(WidgetKind) {
    panel: PanelData,
    label: LabelData,
    button: ButtonData,
    canvas: CanvasData,
    image: ImageWidgetData,
    container: ContainerData,
    scroll_container: ScrollData,

    pub fn luaName(self: WidgetData) []const u8 {
        return switch (self) {
            .panel => "Panel", .label => "Label", .button => "Button",
            .canvas => "Canvas", .image => "Image", .container => "Container", .scroll_container => "ScrollContainer",
        };
    }
};

pub const Widget = struct {
    pub const lua_ref = true;
    pub const lua_name = "WidgetInstance";

    pub const hidden = .{
        "allocator", "diagnostic", "parent", "registry",
        "anchor", "offset", "size", "visible", "resolved", "data",
        "on_mouse_down", "on_mouse_up", "on_drag", "on_mouse_enter", "on_mouse_leave",
        "create", "deinit", "layoutTree", "paint", "clipsChildren",
        "childSlice", "addScroll", "pointerDown", "pointerUp", "pointerDrag", "pointerEnter", "pointerLeave",
    };

    allocator: std.mem.Allocator,
    diagnostic: Diagnostic = .{},
    registry: *WidgetRegistry,
    parent: ?*Widget = null,

    anchor: Anchor,
    offset: types.Vec2,
    size: types.Vec2,
    visible: bool = true,
    resolved: AbsRect = .{ .x = 0, .y = 0, .w = 0, .h = 0 }, // recomputed every frame
    data: WidgetData,

    on_mouse_down: ?Callback = null,
    on_mouse_up: ?Callback = null,
    on_drag: ?Callback = null,
    on_mouse_enter: ?Callback = null,
    on_mouse_leave: ?Callback = null,

    pub fn create(
        allocator: std.mem.Allocator,
        registry: *WidgetRegistry,
        anchor: Anchor,
        offset: types.Vec2,
        size: types.Vec2,
        data: WidgetData,
    ) !*Widget {
        const w = try allocator.create(Widget);
        w.* = .{
            .allocator = allocator,
            .registry = registry,
            .anchor = anchor,
            .offset = offset,
            .size = size,
            .data = data,
        };

        return w;
    }

    fn newChild(self: *Widget, anchor: Anchor, offset: types.Vec2, size: types.Vec2, data: WidgetData) !*Widget {
        const children = self.childrenMut() orelse {
            self.diagnostic.set("{s} cannot hold children", .{self.data.luaName()});
            return error.NotAContainer;
        };

        const w = try Widget.create(self.allocator, self.registry, anchor, offset, size, data);
        w.parent = self;

        errdefer { w.deinit(); self.allocator.destroy(w); }
        try children.append(self.allocator, w);

        return w;
    }

    pub fn Panel(self: *Widget, anchor: Anchor, offset: Vec2, size: Vec2) !Handle(Widget) {
        const w = try self.newChild(anchor, offset.vec, size.vec, .{ .panel = .{ .bg = Color.fromARGB(255, 255, 255, 255) } });
        return .{ .ptr = w };
    }

    pub fn Label(self: *Widget, anchor: Anchor, offset: Vec2, text: []const u8) !Handle(Widget) {
        const owned = try self.allocator.dupe(u8, text);
        errdefer self.allocator.free(owned);

        const w = try self.newChild(anchor, offset.vec, .{ 0, 0 }, .{ .label = .{ .content = .{ .text = owned, .color = Color.fromARGB(255, 255, 255, 255) } } });
        return .{ .ptr = w };
    }

    pub fn Button(self: *Widget, anchor: Anchor, offset: Vec2, size: Vec2, text: []const u8) !Handle(Widget) {
        const owned = try self.allocator.dupe(u8, text);
        errdefer self.allocator.free(owned);

        const w = try self.newChild(anchor, offset.vec, size.vec, .{ .button = .{
            .bg = Color.fromARGB(255, 128, 128, 128),
            .content = .{ .text = owned, .color = Color.fromARGB(255, 255, 255, 255) },
        } });

        return .{ .ptr = w };
    }

    pub fn Canvas(self: *Widget, anchor: Anchor, offset: Vec2, size: Vec2) !Handle(Widget) {
        const w = try self.newChild(anchor, offset.vec, size.vec, .{ .canvas = .{} });
        return .{ .ptr = w };
    }

    pub fn Image(self: *Widget, anchor: Anchor, offset: Vec2, size: Vec2, image: Handle(ImageData)) !Handle(Widget) {
        const w = try self.newChild(anchor, offset.vec, size.vec, .{ .image = .{ .image = image.ptr } });
        return .{ .ptr = w };
    }

    pub fn Container(self: *Widget, anchor: Anchor, offset: Vec2, size: Vec2) !Handle(Widget) {
        const w = try self.newChild(anchor, offset.vec, size.vec, .{ .container = .{} });
        return .{ .ptr = w };
    }

    pub fn ScrollContainer(self: *Widget, anchor: Anchor, offset: Vec2, size: Vec2) !Handle(Widget) {
        const w = try self.newChild(anchor, offset.vec, size.vec, .{ .scroll_container = .{} });
        return .{ .ptr = w };
    }

    fn childrenMut(self: *Widget) ?*WidgetList {
        return switch (self.data) {
            .container => |*c| &c.children,
            .scroll_container => |*c| &c.children,
            else => null,
        };
    }

    pub fn childSlice(self: *Widget) []*Widget {
        return if (self.childrenMut()) |c| c.items else &.{};
    }

    fn layoutOf(self: *Widget) Layout {
        return switch (self.data) {
            .container => |c| c.layout,
            .scroll_container => |c| c.layout,
            else => .absolute,
        };
    }

    fn alignOf(self: *Widget) Align {
        return switch (self.data) {
            .container => |c| c.alignment,
            .scroll_container => |c| c.alignment,
            else => .Start,
        };
    }

    pub fn clipsChildren(self: *Widget) bool {
        return switch (self.data) {
            .container => |c| c.clip,
            .scroll_container => |c| c.clip,
            else => false,
        };
    }

    fn scrollOffset(self: *Widget) types.Vec2 {
        return switch (self.data) {
            .scroll_container => |c| c.scroll,
            else => .{ 0, 0 },
        };
    }

    fn measure(self: *Widget, default_font: *Font) types.Vec2 {
        switch (self.data) {
            .label => |*l| {
                const font = l.content.font orelse default_font;
                const scale = l.content.font_scale;
                if (l.content.measured) |m| {
                    if (l.content.measured_with == font and l.content.measured_scale == scale) return m;
                }

                const sz = font.measure(l.content.text, scale) catch TextSize{ .w = 0, .h = 0 };

                const m = types.Vec2{ @floatFromInt(sz.w), @floatFromInt(sz.h) };
                l.content.measured = m;
                l.content.measured_with = font;
                l.content.measured_scale = scale;

                return m;
            },

            else => return self.size,
        }
    }

    fn resolveWithin(self: *Widget, parent: AbsRect, default_font: *Font) void {
        const s = self.measure(default_font);
        self.size = s;

        const f = self.anchor.factor();
        const ox = parent.x + parent.w * f[0] + self.offset[0] - s[0] * f[0];
        const oy = parent.y + parent.h * f[1] + self.offset[1] - s[1] * f[1];

        self.resolved = .{ .x = @trunc(ox), .y = @trunc(oy), .w = @trunc(s[0]), .h = @trunc(s[1]) };
    }

    pub fn layoutTree(self: *Widget, parent: AbsRect, default_font: *Font) void {
        self.resolveWithin(parent, default_font);
        self.layoutChildren(default_font);
    }

    fn contentRect(self: *Widget) AbsRect {
        const sc = self.scrollOffset();
        return .{ .x = self.resolved.x - sc[0], .y = self.resolved.y - sc[1], .w = self.resolved.w, .h = self.resolved.h };
    }

    fn layoutChildren(self: *Widget, default_font: *Font) void {
        const children = self.childrenMut() orelse return;
        const content = self.contentRect();

        switch (self.layoutOf()) {
            .absolute => {
                var max_w: f32 = 0;
                var max_h: f32 = 0;
                for (children.items) |c| {
                    if (!c.visible) continue;
                    c.layoutTree(content, default_font);
                    const right = (c.resolved.x - content.x) + c.resolved.w;
                    const bottom = (c.resolved.y - content.y) + c.resolved.h;
                    if (right > max_w) max_w = right;
                    if (bottom > max_h) max_h = bottom;
                }

                self.setContentSize(.{ max_w, max_h });
            },
            .stack_vertical => |pad| {
                var total: f32 = 0;
                var max_w: f32 = 0;
                for (children.items) |c| {
                    if (!c.visible) continue;
                    const s = c.measure(default_font);
                    c.size = s;
                    total += s[1] + pad;
                    if (s[0] > max_w) max_w = s[0];
                }
                if (total > 0) total -= pad;

                var cursor = alignOffset(self.alignOf(), content.h, total);
                for (children.items) |c| {
                    if (!c.visible) continue;
                    const s = c.size;
                    const f = c.anchor.factor();
                    c.resolved = .{
                        .x = @trunc(content.x + (content.w - s[0]) * f[0] + c.offset[0]),
                        .y = @trunc(content.y + cursor + c.offset[1]),
                        .w = @trunc(s[0]),
                        .h = @trunc(s[1]),
                    };
                    c.layoutChildren(default_font);
                    cursor += s[1] + pad;
                }

                self.setContentSize(.{ max_w, total });
            },
            .stack_horizontal => |pad| {
                var total: f32 = 0;
                var max_h: f32 = 0;
                for (children.items) |c| {
                    if (!c.visible) continue;
                    const s = c.measure(default_font);
                    c.size = s;
                    total += s[0] + pad;
                    if (s[1] > max_h) max_h = s[1];
                }
                if (total > 0) total -= pad;

                var cursor = alignOffset(self.alignOf(), content.w, total);
                for (children.items) |c| {
                    if (!c.visible) continue;
                    const s = c.size;
                    const f = c.anchor.factor();
                    c.resolved = .{
                        .x = @trunc(content.x + cursor + c.offset[0]),
                        .y = @trunc(content.y + (content.h - s[1]) * f[1] + c.offset[1]),
                        .w = @trunc(s[0]),
                        .h = @trunc(s[1]),
                    };

                    c.layoutChildren(default_font);
                    cursor += s[0] + pad;
                }

                self.setContentSize(.{ total, max_h });
            },
        }

        self.clampScroll();
    }

    fn setContentSize(self: *Widget, v: types.Vec2) void {
        switch (self.data) {
            .scroll_container => |*c| c.content_size = v,
            else => {},
        }
    }

    fn clampScroll(self: *Widget) void {
        switch (self.data) {
            .scroll_container => |*c| {
                const max_x = @max(0, c.content_size[0] - self.resolved.w);
                const max_y = @max(0, c.content_size[1] - self.resolved.h);

                c.scroll[0] = std.math.clamp(c.scroll[0], 0, max_x);
                c.scroll[1] = std.math.clamp(c.scroll[1], 0, max_y);
            },

            else => {},
        }
    }

    pub fn addScroll(self: *Widget, dx: f32, dy: f32) void {
        switch (self.data) {
            .scroll_container => |*c| c.scroll += types.Vec2{ dx, dy },
            else => {},
        }
    }

    fn buttonColor(d: ButtonData) u32 {
        return switch (d.state) {
            .normal => d.bg.color,
            .hover => shade(d.bg.color, 24),
            .pressed => shade(d.bg.color, -24),
        };
    }

    pub fn paint(self: *Widget, p: *Painter) void {
        const x: i32 = @intFromFloat(self.resolved.x);
        const y: i32 = @intFromFloat(self.resolved.y);
        const w: i32 = @intFromFloat(self.resolved.w);
        const h: i32 = @intFromFloat(self.resolved.h);

        switch (self.data) {
            .panel => |d| {
                UIPainter.rect(p.target, x, y, w, h, d.bg.color, p.clip);
                if (d.border_color) |bc| UIPainter.strokeRect(p.target, x, y, w, h, d.border_size, bc.color, p.clip, d.border_top, d.border_bottom, d.border_left, d.border_right);
            },
            .label => |d| {
                const font = d.content.font orelse p.font;
                UIPainter.text(p.target, font, x, y, d.content.text, d.content.color.color, p.clip, d.content.font_scale);
            },
            .button => |d| {
                UIPainter.rect(p.target, x, y, w, h, buttonColor(d), p.clip);
                if (d.border_color) |bc| UIPainter.strokeRect(p.target, x, y, w, h, d.border_size, bc.color, p.clip, d.border_top, d.border_bottom, d.border_left, d.border_right);

                const font = d.content.font orelse p.font;
                const ts = font.measure(d.content.text, d.content.font_scale) catch TextSize{ .w = 0, .h = 0 };
                const tx = x + @divTrunc(w - @as(i32, @intCast(ts.w)), 2);
                const ty = y + @divTrunc(h - @as(i32, @intCast(ts.h)), 2);

                UIPainter.text(p.target, font, tx, ty, d.content.text, d.content.color.color, p.clip, d.content.font_scale);
            },
            .canvas => |d| if (d.on_paint) |cb| cb.call(.{ Handle(Painter){ .ptr = p } }),
            .image => |d| UIPainter.image(p.target, d.image, x, y, w, h, if (d.tint) |t| t.color else null, p.clip),
            .container => |d| {
                if (d.bg) |bg| UIPainter.rect(p.target, x, y, w, h, bg.color, p.clip);
                if (d.border_color) |bc| UIPainter.strokeRect(p.target, x, y, w, h, d.border_size, bc.color, p.clip, d.border_top, d.border_bottom, d.border_left, d.border_right);
            },
            .scroll_container => |d| {
                if (d.bg) |bg| UIPainter.rect(p.target, x, y, w, h, bg.color, p.clip);
                if (d.border_color) |bc| UIPainter.strokeRect(p.target, x, y, w, h, d.border_size, bc.color, p.clip, d.border_top, d.border_bottom, d.border_left, d.border_right);
            },
        }
    }

    // Lua

    pub fn getAnchor(self: Widget) Anchor { return self.anchor; }
    pub fn setAnchor(self: *Widget, v: Anchor) void { self.anchor = v; }

    pub fn getOffset(self: Widget) Vec2 { return .{ .vec = self.offset }; }
    pub fn setOffset(self: *Widget, v: Vec2) void { self.offset = v.vec; }
    pub fn getSize(self: Widget) Vec2 { return .{ .vec = self.size }; }
    pub fn setSize(self: *Widget, v: Vec2) void { self.size = v.vec; }
    pub fn getVisible(self: Widget) bool { return self.visible; }
    pub fn setVisible(self: *Widget, v: bool) void { self.visible = v; }
    pub fn getResolvedPosition(self: Widget) Vec2 {
        return .{ .vec = .{ self.resolved.x, self.resolved.y } };
    }
    pub fn getResolvedSize(self: Widget) Vec2 {
        return .{ .vec = .{ self.resolved.w, self.resolved.h } };
    }
    pub fn getLocalPosition(self: Widget) Vec2 {
        const parent = self.parent orelse return self.getResolvedPosition();
        return .{ .vec = self.getResolvedPosition().vec - parent.getResolvedPosition().vec - parent.scrollOffset() };
    }

    pub fn getFont(self: Widget) ?Handle(Font) {
        const font = switch (self.data) {
            .label => |l| l.content.font,
            .button => |b| b.content.font,
            else => null,
        };
        return .{ .ptr = @constCast(font orelse return null) };
    }

    pub fn setFont(self: *Widget, v: Handle(Font)) !void {
        const c = self.textContent() orelse return error.WidgetHasNoText;
        c.font = v.ptr;
    }

    pub fn getFontScale(self: Widget) ?u32 {
        return switch (self.data) {
            .label => |l| l.content.font_scale,
            .button => |l| l.content.font_scale,
            else => null
        };
    }

    pub fn setFontScale(self: *Widget, v: u32) !void {
        const c = self.textContent() orelse return error.WidgetHasNoText;
        c.font_scale = v;
    }

    pub fn getBg(self: Widget) ?Color {
        return switch (self.data) {
            .panel => |p| p.bg,
            .button => |b| b.bg,
            .container => |c| c.bg,
            .scroll_container => |c| c.bg,
            else => null,
        };
    }
    pub fn setBg(self: *Widget, v: Color) !void {
        switch (self.data) {
            .panel => |*p| p.bg = v,
            .button => |*b| b.bg = v,
            .container => |*c| c.bg = v,
            .scroll_container => |*c| c.bg = v,
            else => { self.diagnostic.set("{s} has no background", .{self.data.luaName()}); return error.WidgetHasNoBackground; },
        }
    }

    pub fn getBorderColor(self: Widget) ?Color {
        return switch (self.data) {
            .panel => |p| p.border_color,
            .button => |b| b.border_color,
            .container => |c| c.border_color,
            .scroll_container => |c| c.border_color,
            else => null,
        };
    }
    pub fn setBorderColor(self: *Widget, v: Color) !void {
        switch (self.data) {
            .panel => |*p| p.border_color = v,
            .button => |*b| b.border_color = v,
            .container => |*c| c.border_color = v,
            .scroll_container => |*c| c.border_color = v,
            else => { self.diagnostic.set("{s} has no border color", .{self.data.luaName()}); return error.WidgetHasNoBorder; },
        }
    }

    pub fn getBorderSize(self: Widget) ?i32 {
        return switch (self.data) {
            .panel => |p| p.border_size,
            .button => |b| b.border_size,
            .container => |c| c.border_size,
            .scroll_container => |c| c.border_size,
            else => null,
        };
    }
    pub fn setBorderSize(self: *Widget, v: i32) !void {
        switch (self.data) {
            .panel => |*p| p.border_size = v,
            .button => |*b| b.border_size = v,
            .container => |*c| c.border_size = v,
            .scroll_container => |*c| c.border_size = v,
            else => { self.diagnostic.set("{s} has no border size", .{self.data.luaName()}); return error.WidgetHasNoBorder; },
        }
    }

    pub fn getBorderTop(self: Widget) ?bool {
        return switch (self.data) {
            .panel => |p| p.border_top,
            .button => |b| b.border_top,
            .container => |c| c.border_top,
            .scroll_container => |c| c.border_top,
            else => null,
        };
    }
    pub fn setBorderTop(self: *Widget, v: bool) !void {
        switch (self.data) {
            .panel => |*p| p.border_top = v,
            .button => |*b| b.border_top = v,
            .container => |*c| c.border_top = v,
            .scroll_container => |*c| c.border_top = v,
            else => { self.diagnostic.set("{s} has no border", .{self.data.luaName()}); return error.WidgetHasNoBorder; },
        }
    }
    pub fn getBorderBottom(self: Widget) ?bool {
        return switch (self.data) {
            .panel => |p| p.border_bottom,
            .button => |b| b.border_bottom,
            .container => |c| c.border_bottom,
            .scroll_container => |c| c.border_bottom,
            else => null,
        };
    }
    pub fn setBorderBottom(self: *Widget, v: bool) !void {
        switch (self.data) {
            .panel => |*p| p.border_bottom = v,
            .button => |*b| b.border_bottom = v,
            .container => |*c| c.border_bottom = v,
            .scroll_container => |*c| c.border_bottom = v,
            else => { self.diagnostic.set("{s} has no border", .{self.data.luaName()}); return error.WidgetHasNoBorder; },
        }
    }
    pub fn getBorderLeft(self: Widget) ?bool {
        return switch (self.data) {
            .panel => |p| p.border_left,
            .button => |b| b.border_left,
            .container => |c| c.border_left,
            .scroll_container => |c| c.border_left,
            else => null,
        };
    }
    pub fn setBorderLeft(self: *Widget, v: bool) !void {
        switch (self.data) {
            .panel => |*p| p.border_left = v,
            .button => |*b| b.border_left = v,
            .container => |*c| c.border_left = v,
            .scroll_container => |*c| c.border_left = v,
            else => { self.diagnostic.set("{s} has no border", .{self.data.luaName()}); return error.WidgetHasNoBorder; },
        }
    }
    pub fn getBorderRight(self: Widget) ?bool {
        return switch (self.data) {
            .panel => |p| p.border_right,
            .button => |b| b.border_right,
            .container => |c| c.border_right,
            .scroll_container => |c| c.border_right,
            else => null,
        };
    }
    pub fn setBorderRight(self: *Widget, v: bool) !void {
        switch (self.data) {
            .panel => |*p| p.border_right = v,
            .button => |*b| b.border_right = v,
            .container => |*c| c.border_right = v,
            .scroll_container => |*c| c.border_right = v,
            else => { self.diagnostic.set("{s} has no border", .{self.data.luaName()}); return error.WidgetHasNoBorder; },
        }
    }

    pub fn getText(self: Widget) ?[]const u8 {
        return switch (self.data) { .label => |l| l.content.text, .button => |b| b.content.text, else => null };
    }
    pub fn getTextColor(self: Widget) ?Color {
        return switch (self.data) { .label => |l| l.content.color, .button => |b| b.content.color, else => null };
    }
    pub fn setText(self: *Widget, v: []const u8) !void {
        const c = self.textContent() orelse return error.WidgetHasNoText;
        self.allocator.free(c.text);
        c.text = try self.allocator.dupe(u8, v);
    }
    pub fn setTextColor(self: *Widget, v: Color) !void {
        const c = self.textContent() orelse return error.WidgetHasNoText;
        c.color = v;
    }

    pub fn getClip(self: Widget) bool {
        return switch (self.data) { .container => |c| c.clip, .scroll_container => |c| c.clip, else => false };
    }

    pub fn setClip(self: *Widget, v: bool) !void {
        switch (self.data) {
            .container => |*c| c.clip = v,
            .scroll_container => |*c| c.clip = v,
            else => { self.diagnostic.set("{s} is not a container", .{self.data.luaName()}); return error.NotAContainer; },
        }
    }

    pub fn getAlign(self: Widget) Align {
        return switch (self.data) {
            .container => |c| c.alignment,
            .scroll_container => |c| c.alignment,
            else => .Start,
        };
    }
    pub fn setAlign(self: *Widget, v: Align) !void {
        switch (self.data) {
            .container => |*c| c.alignment = v,
            .scroll_container => |*c| c.alignment = v,
            else => { self.diagnostic.set("{s} is not a container", .{self.data.luaName()}); return error.NotAContainer; },
        }
    }

    pub fn getTint(self: Widget) ?Color {
        return switch (self.data) { .image => |i| i.tint, else => null };
    }
    pub fn setTint(self: *Widget, v: Color) !void {
        switch (self.data) {
            .image => |*i| i.tint = v,
            else => { self.diagnostic.set("{s} has no tint", .{self.data.luaName()}); return error.NotAnImage; },
        }
    }

    pub fn getImage(self: Widget) ?Handle(ImageData) {
        return switch (self.data) { .image => |i| .{ .ptr = i.image }, else => null };
    }
    pub fn setImage(self: *Widget, v: Handle(ImageData)) !void {
        switch (self.data) {
            .image => |*i| i.image = v.ptr,
            else => { self.diagnostic.set("{s} is not an image", .{self.data.luaName()}); return error.NotAnImage; },
        }
    }

    pub fn getScroll(self: Widget) Vec2 {
        return .{ .vec = switch (self.data) { .scroll_container => |c| c.scroll, else => types.Vec2{ 0, 0 } } };
    }
    pub fn setScroll(self: *Widget, v: Vec2) !void {
        switch (self.data) {
            .scroll_container => |*c| c.scroll = v.vec,
            else => { self.diagnostic.set("{s} does not scroll", .{self.data.luaName()}); return error.NotScrollable; },
        }
    }

    pub fn StackVertical(self: *Widget, padding: f32) !void { try self.setLayout(.{ .stack_vertical = padding }); }
    pub fn StackHorizontal(self: *Widget, padding: f32) !void { try self.setLayout(.{ .stack_horizontal = padding }); }
    pub fn AbsoluteLayout(self: *Widget) !void { try self.setLayout(.absolute); }

    fn setLayout(self: *Widget, l: Layout) !void {
        switch (self.data) {
            .container => |*c| c.layout = l,
            .scroll_container => |*c| c.layout = l,
            else => { self.diagnostic.set("{s} is not a container", .{self.data.luaName()}); return error.NotAContainer; },
        }
    }

    pub fn OnClick(self: *Widget, cb: Callback) !void {
        switch (self.data) {
            .button => |*b| b.on_click = cb,
            else => { self.diagnostic.set("OnClick is only valid on buttons, got {s}", .{self.data.luaName()}); return error.NotClickable; },
        }
    }

    pub fn OnPaint(self: *Widget, cb: Callback) !void {
        switch (self.data) {
            .canvas => |*c| c.on_paint = cb,
            else => { self.diagnostic.set("OnPaint is only valid on canvases, got {s}", .{self.data.luaName()}); return error.NotACanvas; },
        }
    }

    pub fn OnMouseDown(self: *Widget, cb: Callback) !void { self.on_mouse_down = cb; }
    pub fn OnMouseUp(self: *Widget, cb: Callback) !void { self.on_mouse_up = cb; }
    pub fn OnDrag(self: *Widget, cb: Callback) !void { self.on_drag = cb; }
    pub fn OnMouseEnter(self: *Widget, cb: Callback) !void { self.on_mouse_enter = cb; }
    pub fn OnMouseLeave(self: *Widget, cb: Callback) !void { self.on_mouse_leave = cb; }

    pub fn pointerDown(self: *Widget, pos: Vec2) void {
        var cur: ?*Widget = self;
        while (cur) |c| : (cur = c.parent) if (c.on_mouse_down) |cb| { cb.call(.{pos}); return; };
    }
    pub fn pointerUp(self: *Widget, pos: Vec2) void {
        var cur: ?*Widget = self;
        while (cur) |c| : (cur = c.parent) if (c.on_mouse_up) |cb| { cb.call(.{pos}); return; };
    }
    pub fn pointerDrag(self: *Widget, delta: Vec2) void {
        var cur: ?*Widget = self;
        while (cur) |c| : (cur = c.parent) if (c.on_drag) |cb| { cb.call(.{delta}); return; };
    }

    pub fn pointerEnter(self: *Widget) void { if (self.on_mouse_enter) |cb| cb.call(.{}); }
    pub fn pointerLeave(self: *Widget) void { if (self.on_mouse_leave) |cb| cb.call(.{}); }

    pub fn GetChildCount(self: *Widget) usize { return self.childSlice().len; }

    pub fn GetChild(self: *Widget, index: usize) !Handle(Widget) {
        const s = self.childSlice();
        if (index < 1 or index > s.len) {
            self.diagnostic.set("child index {d} out of range (1..{d})", .{ index, s.len });

            return error.OutOfRange;
        }

        return .{ .ptr = s[index - 1] };
    }

    pub fn Clear(self: *Widget) void {
        const children = self.childrenMut() orelse return;
        for (children.items) |c| { c.deinit(); self.allocator.destroy(c); }

        children.clearRetainingCapacity();
    }

    pub fn Remove(self: *Widget) void {
        if (self.parent) |p| {
            if (p.childrenMut()) |siblings| {
                for (siblings.items, 0..) |c, i| if (c == self) { _ = siblings.swapRemove(i); break; };
            }

            self.deinit();
            self.allocator.destroy(self);
        } else {
            self.registry.removeWidget(self);
        }
    }


    fn textContent(self: *Widget) ?*TextContent {
        const c = switch (self.data) { .label => |*l| &l.content, .button => |*b| &b.content, else => null };
        if (c) |content| content.measured = null;
        return c;
    }

    pub fn deinit(self: *Widget) void {
        if (self.registry.hovered == self) self.registry.hovered = null;
        if (self.registry.pressed == self) self.registry.pressed = null;

        if (self.on_mouse_down) |cb| cb.deinit();
        if (self.on_mouse_up) |cb| cb.deinit();
        if (self.on_drag) |cb| cb.deinit();
        if (self.on_mouse_enter) |cb| cb.deinit();
        if (self.on_mouse_leave) |cb| cb.deinit();

        switch (self.data) {
            .label => |l| self.allocator.free(l.content.text),
            .button => |b| { self.allocator.free(b.content.text); if (b.on_click) |cb| cb.deinit(); },
            .canvas => |c| { if (c.on_paint) |cb| cb.deinit(); },
            .image => {},
            .container => |*c| {
                for (c.children.items) |child| { child.deinit(); self.allocator.destroy(child); }
                c.children.deinit(self.allocator);
            },
            .scroll_container => |*c| {
                for (c.children.items) |child| { child.deinit(); self.allocator.destroy(child); }
                c.children.deinit(self.allocator);
            },
            .panel => {},
        }
    }
};

fn shade(color: u32, delta: i32) u32 {
    const a = color & 0xFF000000;
    const r = channel(@intCast((color >> 16) & 0xFF), delta);
    const g = channel(@intCast((color >> 8) & 0xFF), delta);
    const b = channel(@intCast(color & 0xFF), delta);

    return a | (r << 16) | (g << 8) | b;
}

fn channel(v: i32, delta: i32) u32 {
    return @intCast(std.math.clamp(v + delta, 0, 255));
}
