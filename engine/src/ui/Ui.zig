// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const core = @import("../core/core.zig");
const math = @import("../core/math/math.zig");
const render = @import("../render/render.zig");
const reflow = @import("reflow.zig");
pub const types = @import("types.zig");

const u64_max = std.math.maxInt(u64);

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
    borders: ecs.ComponentId
};

const Ui = @This();
allocator: std.mem.Allocator,
frame_allocator: std.heap.ArenaAllocator,
component_ids: ComponentIds,
world: ecs.World,
changed: std.ArrayList(ecs.Entity),

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
            .borders = borders
        },
    };
}

pub fn deinit(self: *Ui) void {
    self.world.deinit();
    self.frame_allocator.deinit();
}

pub fn update(self: *Ui) void {
    const changed = &self.world.hierarchy.changed;
    if (changed.items.len == 0) return;

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
    parent: ?ecs.Entity = null,
    size: ?types.SizeMode = null,
    position: ?math.Vec2 = null,
    layout: ?types.Layout = null,
    color: ?core.Color = null,
    opacity: ?f32 = null,
    text: ?types.Text = null,
    image: ?types.Image = null,
    corner_radii: ?types.CornerRadii = null,
    borders: ?types.Borders = null,
};

pub fn createElement(self: *Ui, options: ?CreateOptions) !ecs.Entity {
    const entity = try self.world.spawnEntity();
    errdefer entity.destroy();

    const opts = options orelse return entity;
    if (opts.parent) |p| try entity.setParent(p);
    if (opts.size) |s| try self.world.set(entity, self.component_ids.size, types.SizeMode, s);
    if (opts.position) |p| try self.world.set(entity, self.component_ids.position, math.Vec2, p);
    if (opts.layout) |l| try self.world.set(entity, self.component_ids.layout, types.Layout, l);
    if (opts.color) |c| try self.world.set(entity, self.component_ids.color, core.Color, c);
    if (opts.opacity) |o| try self.world.set(entity, self.component_ids.opacity, f32, o);
    if (opts.text) |t| try self.world.set(entity, self.component_ids.text, types.Text, t);
    if (opts.image) |i| try self.world.set(entity, self.component_ids.image, types.Image, i);
    if (opts.corner_radii) |c| try self.world.set(entity, self.component_ids.corner_radii, types.CornerRadii, c);
    if (opts.borders) |b| try self.world.set(entity, self.component_ids.borders, types.Borders, b);

    return entity;
}

const bind = @import("../scripting/bind/bind.zig");
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
        bind.func("CreateElement", Ui.createElement)
    }
});
