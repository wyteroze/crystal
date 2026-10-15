// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const bind = @import("../scripting/bind/bind.zig");
const ecs = @import("../ecs/ecs.zig");
const core = @import("../core/core.zig");
const math = @import("../core/math/math.zig");
const render = @import("../render/render.zig");
const reflow = @import("reflow.zig");
pub const types = @import("types.zig");

const u64_max = std.math.maxInt(u64);

pub const Interactable = bool;
pub const PointerSignal = core.signal.Signal(.{ math.Vec2 });
pub const ElementSignals = struct {
    // Nullable until Lua access them.
    // We can't really know for certain what it does
    // with an event that it accesses (like, `_ = elem.Pressed` for some reason),
    // but it's uncommon for someone to just access a signal for no reason.
    // This behavior should be documented in the future.
    pointer_down: ?*PointerSignal = null,
    pointer_up: ?*PointerSignal = null,
    activated: ?*PointerSignal = null,
    pointer_entered: ?*PointerSignal = null,
    pointer_moved: ?*PointerSignal = null,
    pointer_left: ?*PointerSignal = null,

    pub fn deinit(self: *ElementSignals) void {
        const info = @typeInfo(ElementSignals).@"struct";
        inline for (info.field_names) |nm| if (@field(self, nm)) |s| s.retire();
    }
};

pub const ComponentIds = struct {
    position: ecs.ComponentId,
    size: ecs.ComponentId,
    layout: ecs.ComponentId,
    color: ecs.ComponentId,
    opacity: ecs.ComponentId,
    text: ecs.ComponentId,
    render_view: ecs.ComponentId,
    computed_size: ecs.ComponentId,
    computed_position: ecs.ComponentId,
    computed_text_layout: ecs.ComponentId,
    image: ecs.ComponentId,
    corner_radii: ecs.ComponentId,
    borders: ecs.ComponentId,
    signals: ecs.ComponentId,
    interactable: ecs.ComponentId
};

const Ui = @This();
allocator: std.mem.Allocator,
frame_allocator: std.heap.ArenaAllocator,
component_ids: ComponentIds,
world: ecs.World,
changed: std.ArrayList(ecs.Entity),

pressed: ?ecs.Entity = null,
hovered: ?ecs.Entity = null,
pointer_pos: math.Vec2 = .zero,
roots: std.ArrayList(ecs.Entity) = .empty,

pub fn init(allocator: std.mem.Allocator) !Ui {
    var world: ecs.World = .init(allocator);

    const position = try world.registerComponent(math.Vec2, "Position");
    const size = try world.registerComponent(types.SizeMode, "Size");
    const layout = try world.registerComponent(types.Layout, "Layout");
    const color = try world.registerComponent(core.Color, "Color");
    const opacity = try world.registerComponent(f32, "Opacity");
    const text = try world.registerComponent(Ui.types.Text, "Text");
    const render_view = try world.registerComponent(types.RenderViewOptions, "RenderView");
    const computed_size = try world.registerComponent(math.Vec2, "ComputedSize");
    const computed_position = try world.registerComponent(math.Vec2, "ComputedPosition");
    const computed_text_layout = try world.registerComponent(types.ComputedTextLayout, "ComputedTextLayout");
    const image = try world.registerComponent(types.Image, "Image");
    const corner_radii = try world.registerComponent(Ui.types.CornerRadii, "CornerRadii");
    const borders = try world.registerComponent(Ui.types.Borders, "Borders");
    const signals = try world.registerComponent(ElementSignals, "ElementSignals");
    const interactable = try world.registerComponent(Interactable, "Interactable");

    return .{
        .allocator = allocator,
        .frame_allocator = .init(allocator),
        .world = world,
        .changed = .empty,
        .component_ids = .{
            .position = position,
            .size = size,
            .layout = layout,
            .color = color,
            .corner_radii = corner_radii,
            .opacity = opacity,
            .text = text,
            .render_view = render_view,
            .computed_size = computed_size,
            .computed_position = computed_position,
            .computed_text_layout = computed_text_layout,
            .image = image,
            .borders = borders,
            .signals = signals,
            .interactable = interactable
        },
    };
}

pub fn deinit(self: *Ui) void {
    self.world.deinit();
    self.roots.deinit(self.allocator);
    self.frame_allocator.deinit();
}

pub fn update(self: *Ui) void {
    self.world.dispatcher.flush();

    const changed = &self.world.hierarchy.changed;
    if (changed.items.len == 0) return;
    for (changed.items) |e| {
        if (!e.isAlive() or e.getParent() != null) continue;
        const known = for (self.roots.items) |r| {
            if (r.eql(e)) break true;
        } else false;
        
        if (!known) self.roots.append(self.allocator, e) catch @panic("Out of memory");
    }

    reflow.reflowUi(&self.world, self.component_ids, changed.items, self.allocator, self.frame_allocator.allocator());
    _ = self.frame_allocator.reset(.retain_capacity);
    changed.clearRetainingCapacity();
    self.world.changed_set.clearRetainingCapacity();
}

fn freeTextLayout(allocator: std.mem.Allocator, bytes: []u8) void {
    const l: *types.ComputedTextLayout = @ptrCast(@alignCast(bytes.ptr));
    allocator.free(l.quads);
}

pub const CreateOptions = struct {
    parent: ?Element = null,
    size: ?types.SizeMode = null,
    position: ?math.Vec2 = null,
    layout: ?types.Layout = null,
    color: ?core.Color = null,
    opacity: ?f32 = null,
    text: ?types.Text = null,
    image: ?types.Image = null,
    corner_radii: ?types.CornerRadii = null,
    borders: ?types.Borders = null,
    interactable: ?Interactable = null,
};

pub fn createElement(self: *Ui, options: ?CreateOptions) !Element {
    const entity = try self.world.spawnEntity();
    errdefer entity.destroy();

    const opts = options orelse return .{ .entity = entity };
    if (opts.parent) |p| try entity.setParent(p.entity);
    try self.world.set(entity, self.component_ids.interactable, Interactable, if (opts.interactable) |i| i else true);
    try self.world.set(entity, self.component_ids.size, types.SizeMode, if (opts.size) |s| s else .{});
    try self.world.set(entity, self.component_ids.position, math.Vec2, if (opts.position) |p| p else .zero);
    try self.world.set(entity, self.component_ids.color, core.Color, if (opts.color) |c| c else .{});
    try self.world.set(entity, self.component_ids.opacity, f32, if (opts.opacity) |o| o else 1);
    try self.world.set(entity, self.component_ids.borders, types.Borders, if (opts.borders) |b| b else .{});
    try self.world.set(entity, self.component_ids.corner_radii, types.CornerRadii, if (opts.corner_radii) |c| c else .{});

    if (opts.layout) |l| try self.world.set(entity, self.component_ids.layout, types.Layout, l);
    if (opts.text) |t| try self.world.set(entity, self.component_ids.text, types.Text, t);
    if (opts.image) |i| try self.world.set(entity, self.component_ids.image, types.Image, i);

    return .{ .entity = entity };
}

pub fn getSignal(self: *Ui, e: ecs.Entity, comptime field: []const u8) !*PointerSignal {
    const id = self.component_ids.signals;
    if (e.getComponent(id, ElementSignals) == null)
        try self.world.set(e, id, ElementSignals, .{});
    
    const s = e.getComponent(id, ElementSignals).?;
    if (@field(s, field) == null)
        @field(s, field) = try PointerSignal.create(self.allocator, &self.world.dispatcher);

    return @field(s, field).?;
}

// Used by `Input`

pub fn pointerPressed(self: *Ui, pos: math.Vec2) bool {
    self.updateHover(pos);
    const t = self.hitTestRoots(pos) orelse return false;

    self.pressed = t;
    self.bubble("pointer_down", t, pos);

    return true;
}

pub fn pointerReleased(self: *Ui, pos: math.Vec2) bool {
    const pressed = self.pressed orelse return false;
    defer self.pressed = null;

    if (!pressed.isAlive()) return true;
    if (self.hitTestRoots(pos)) |hit| {
        self.bubble("pointer_up", hit, pos);
        if (selfOrAncestor(pressed, hit))
            self.bubble("activated", pressed, pos);
    }

    return true;
}

pub fn pointerMoved(self: *Ui, pos: math.Vec2) bool {
    self.updateHover(pos);
    return self.pressed != null;
}

fn selfOrAncestor(maybe_ancestor: ecs.Entity, e: ecs.Entity) bool {
    var cur: ?ecs.Entity = e;
    while (cur) |c| : (cur = c.getParent()) if (c.eql(maybe_ancestor)) return true;
    return false;
}

fn bubble(self: *Ui, comptime field: []const u8, target: ecs.Entity, pos: math.Vec2) void {
    var cur: ?ecs.Entity = target;
    while (cur) |e| : (cur = e.getParent()) {
        const s = e.getComponent(self.component_ids.signals, ElementSignals) orelse continue;
        if (@field(s, field)) |sig| sig.fire(.{ pos });
    }
}

fn isInteractive(self: *Ui, e: ecs.Entity) bool {
    if (e.getComponent(self.component_ids.interactable, Interactable)) |i| return i.*;
    return e.getComponent(self.component_ids.signals, ElementSignals) != null;
}

fn hitTest(self: *Ui, e: ecs.Entity, p: math.Vec2) ?ecs.Entity {
    const pos = e.getComponent(self.component_ids.computed_position, math.Vec2) orelse return null;
    const size = e.getComponent(self.component_ids.computed_size, math.Vec2) orelse return null;

    if (p.x < pos.x or p.y < pos.y or p.x >= pos.x + size.x or p.y >= pos.y + size.y) return null;

    const children = e.getChildren();
    var i = children.len;
    while (i > 0) {
        i -= 1;
        if (self.hitTest(children[i], p)) |hit| 
            return hit;
    }

    return if (self.isInteractive(e)) e 
        else null;
}

fn hitTestRoots(self: *Ui, p: math.Vec2) ?ecs.Entity {
    var i = self.roots.items.len;
    while (i > 0) {
        i -= 1;

        const r = self.roots.items[i];
        if (!r.isAlive() or r.getParent() != null) { _ = self.roots.orderedRemove(i); continue; }
        if (self.hitTest(r, p)) |hit| return hit;
    }

    return null;
}

fn fireOwn(self: *Ui, comptime field: []const u8, e: ecs.Entity, pos: math.Vec2) void {
    const s = e.getComponent(self.component_ids.signals, ElementSignals) orelse return;
    if (@field(s, field)) |sig| sig.fire(.{ pos });
}

fn setHover(self: *Ui, new: ?ecs.Entity, pos: math.Vec2) void {
    var old = self.hovered;
    if (old) |o| if (!o.isAlive()) { old = null; };

    const same = if (old != null and new != null) old.?.eql(new.?) else old == null and new == null;
    if (same) return;
    self.hovered = new;

    var cur = old;
    while (cur) |e| : (cur = e.getParent()) {
        if (new) |n| if (selfOrAncestor(e, n)) break;
        self.fireOwn("pointer_left", e, pos);
    }

    var chain: [32]ecs.Entity = undefined;
    var len: usize = 0;
    cur = new;

    while (cur) |e| : (cur = e.getParent()) {
        if (old) |o| if (selfOrAncestor(e, o)) break;
        if (len == chain.len) break;
        chain[len] = e;
        len += 1;
    }

    while (len > 0) {
        len -= 1;
        self.fireOwn("pointer_entered", chain[len], pos);
    }
}

fn updateHover(self: *Ui, pos: math.Vec2) void {
    self.pointer_pos = pos;
    const hit = self.hitTestRoots(pos);
    self.setHover(hit, pos);

    const target = self.pressed orelse hit orelse return;
    if (target.isAlive()) self.bubble("pointer_moved", target, pos);
}

pub const api = bind.module("ui", .{
    .kind = .{ .singleton = Ui },
    .members = &.{
        bind.record(types.Padding, .{}),
        bind.record(types.CornerRadii, .{}),
        bind.record(types.SizeMode, .{}),
        bind.record(types.Text, .{}),
        bind.record(types.Crop, .{}),
        bind.record(types.Image, .{}),
        bind.record(types.Borders, .{}),
        bind.record(types.GridLayout, .{}),
        bind.variant(types.SizeAxis, .{ .number = .fixed }),
        bind.variant(types.GridAxis, .{ .number = .fixed }),
        bind.func("CreateElement", Ui.createElement),
        Element.sub_api
    }
});

pub const Element = struct {
    entity: ecs.Entity,

    const ToEntity = bind.Via(Element, ecs.Entity, struct {
        fn f(e: Element) ecs.Entity { return e.entity; }
    }.f);

    pub const sub_api = bind.handle(Element, .{
        .alive = bind.func("isAlive", struct { fn c(self: Element) bool { return self.entity.isAlive(); } }.c),
        .inherit = bind.inherit(Element.ToEntity, ecs.Entity.sub_api.impl.recipe),
        .signals = &.{
            // `ui` argument is provided by marshaller
            bind.signal("PointerDown", struct {
                fn c(self: Element, ui: *Ui) !*PointerSignal { return ui.getSignal(self.entity, "pointer_down"); }
            }.c),
            bind.signal("PointerUp", struct {
                fn c(self: Element, ui: *Ui) !*PointerSignal { return ui.getSignal(self.entity, "pointer_up"); }
            }.c),
            bind.signal("Activated", struct {
                fn c(self: Element, ui: *Ui) !*PointerSignal { return ui.getSignal(self.entity, "activated"); }
            }.c),
            bind.signal("PointerEntered", struct {
                fn c(self: Element, ui: *Ui) !*PointerSignal { return ui.getSignal(self.entity, "pointer_entered"); }
            }.c),
            bind.signal("PointerMoved", struct {
                fn c(self: Element, ui: *Ui) !*PointerSignal { return ui.getSignal(self.entity, "pointer_moved"); }
            }.c),
            bind.signal("PointerLeft", struct {
                fn c(self: Element, ui: *Ui) !*PointerSignal { return ui.getSignal(self.entity, "pointer_left"); }
            }.c),
        }
    });
};