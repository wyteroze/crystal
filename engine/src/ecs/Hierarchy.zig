// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Entity = @import("Entity.zig");

const Hierarchy = @This();
allocator: std.mem.Allocator,
parents: std.ArrayList(Entity),
children: std.ArrayList(std.ArrayList(Entity)),
/// This gets added to whenever the parents of entities are changed.
/// This is used mainly in the UI system by reading it every frame,
/// reflowing the hierarchy, then clearing it so it can be read the next frame.
/// If you don't need to use it, it's a good idea to clear it every frame regardless
/// so it doesn't infinitely grow during the program's lifetime.
changed: std.ArrayList(Entity),

pub fn init(allocator: std.mem.Allocator) Hierarchy {
    return .{
        .allocator = allocator,
        .parents = .empty,
        .children = .empty,
        .changed = .empty
    };
}

pub fn deinit(self: *Hierarchy) void {
    for (self.children.items) |*i| i.deinit(self.allocator);
    self.children.deinit(self.allocator);
    self.parents.deinit(self.allocator);
    self.changed.deinit(self.allocator);
}

pub fn setParent(self: *Hierarchy, entity: Entity, parent: ?Entity) !void {
    try self.ensureCapacity(entity.index);

    if (parent) |p| {
        try self.ensureCapacity(p.index);
        if (p.eql(entity)) return error.CantParentToSelf;
        if (self.isAncestorOf(entity, p)) return error.CyclicParent;
    }

    const new_parent = parent orelse Entity.invalid;
    const previous_parent = self.parents.items[entity.index];
    if (previous_parent.eql(new_parent)) return;

    if (!previous_parent.eql(Entity.invalid)) {
        self.removeChild(previous_parent, entity);
        try self.changed.append(self.allocator, previous_parent);
    }

    self.parents.items[entity.index] = parent orelse Entity.invalid;

    if (parent) |p| {
        try self.children.items[p.index].append(self.allocator, entity);
        try self.changed.append(self.allocator, p);
    }

    try self.changed.append(self.allocator, entity);
}

fn removeChild(self: *Hierarchy, parent: Entity, child: Entity) void {
    const list = &self.children.items[parent.index];
    for (list.items, 0..) |e, i| {
        if (e.eql(child)) {
            _ = list.orderedRemove(i);
            return;
        }
    }
}

pub fn isAncestorOf(self: *Hierarchy, entity: Entity, ancestor: Entity) bool {
    var current = self.getParent(ancestor);
    while (current) |p| {
        if (p.eql(entity)) return true;
        current = self.getParent(p);
    }

    return false;
}

pub fn getParent(self: *const Hierarchy, entity: Entity) ?Entity {
    if (entity.index >= self.parents.items.len) return null;
    const parent = self.parents.items[entity.index];

    return if (parent.eql(Entity.invalid)) null else parent;
}

pub fn getChildren(self: *const Hierarchy, entity: Entity) []const Entity {
    if (entity.index >= self.children.items.len) return &.{};
    return self.children.items[entity.index].items;
}

pub fn popChild(self: *Hierarchy, entity: Entity) ?Entity {
    if (entity.index >= self.children.items.len) return null;
    return self.children.items[entity.index].pop();
}

pub fn remove(self: *Hierarchy, entity: Entity) void {
    if (entity.index >= self.parents.items.len) return;

    const parent = self.parents.items[entity.index];
    if (!parent.eql(Entity.invalid)) {
        self.removeChild(parent, entity);
        self.changed.append(self.allocator, parent) catch {};
    }

    self.parents.items[entity.index] = Entity.invalid;
    self.children.items[entity.index].clearRetainingCapacity();
}

fn ensureCapacity(self: *Hierarchy, index: u32) !void {
    while (self.parents.items.len <= index) {
        try self.parents.append(self.allocator, Entity.invalid);
        try self.children.append(self.allocator, .empty);
    }
}