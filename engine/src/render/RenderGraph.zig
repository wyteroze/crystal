// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const pass = @import("pass/pass.zig");
const resource = @import("resource.zig");

const RenderGraph = @This();
allocator: std.mem.Allocator,
nodes: std.ArrayList(pass.PassNode),
sorted: std.ArrayList(pass.PassNode),
resources: resource.ResourceTable,
external_resources: std.AutoHashMap(u64, void),
// Needs to be recompiled
dirty: bool,

pub fn init(allocator: std.mem.Allocator) RenderGraph {
    return .{
        .allocator = allocator,
        .nodes = .empty,
        .sorted = .empty,
        .resources = .init(allocator),
        .external_resources = .init(allocator),
        .dirty = true
    };
}

pub fn deinit(self: *RenderGraph) void {
    for (self.nodes.items) |n| n.deinit(self.allocator);
    self.nodes.deinit(self.allocator);
    self.sorted.deinit(self.allocator);
    self.resources.deinit();
    self.external_resources.deinit();
}

pub fn addNode(self: *RenderGraph, node: pass.PassNode) !void {
    try self.nodes.append(self.allocator, node);
    self.dirty = true;
}

pub fn markExternal(self: *RenderGraph, ref: resource.ResourceRef) !void {
    try self.external_resources.put(ref.id, {});
}

pub fn compile(self: *RenderGraph) !void {
    self.sorted.clearRetainingCapacity();

    var producer_of: std.AutoHashMap(u64, usize) = .init(self.allocator);
    defer producer_of.deinit();

    for (self.nodes.items, 0..) |n, i| {
        for (n.writes) |w| {
            const result = try producer_of.getOrPut(w.id);
            if (result.found_existing) {
                std.log.err("resource '{s}' is written by both '{s}' and '{s}'", .{
                    w.name, self.nodes.items[result.value_ptr.*].name, n.name
                });

                return error.DuplicateResourceWriter;
            }

            result.value_ptr.* = i;
        }
    }

    var in_degree = try self.allocator.alloc(usize, self.nodes.items.len);
    defer self.allocator.free(in_degree);
    @memset(in_degree, 0);

    var edges: std.AutoHashMap(usize, std.ArrayList(usize)) = .init(self.allocator);
    defer {
        var iter = edges.valueIterator();

        while (iter.next()) |list| list.deinit(self.allocator);
        edges.deinit();
    }

    for (self.nodes.items, 0..) |node, i| {
        for (node.reads) |r| {
            if (self.external_resources.contains(r.id)) continue;
            const producer_idx = producer_of.get(r.id) orelse {
                std.log.err("Node '{s}' reads resource '{s}', but no node writes it.", .{ node.name, r.name });
                return error.UnsatisfiedDependency;
            };

            const entry = try edges.getOrPut(producer_idx);
            if (!entry.found_existing) entry.value_ptr.* = .empty;
            try entry.value_ptr.append(self.allocator, i);
            in_degree[i] += 1;
        }
    }

    var queue: std.ArrayList(usize) = .empty;
    defer queue.deinit(self.allocator);
    var cursor: usize = 0;

    for (in_degree, 0..) |deg, i| {
        if (deg == 0) try queue.append(self.allocator, i);
    }

    while (cursor < queue.items.len) {
        const idx = queue.items[cursor];
        cursor += 1;
        try self.sorted.append(self.allocator, self.nodes.items[idx]);

        if (edges.get(idx)) |d| {
            for (d.items) |i| {
                in_degree[i] -= 1;
                if (in_degree[i] == 0) try queue.append(self.allocator, i);
            }
        }
    }

    if (self.sorted.items.len != self.nodes.items.len) {
        std.log.err("Render graph has cyclic dependency", .{});
        return error.CyclicDependency;
    }

    self.dirty = false;
}

pub fn execute(self: *RenderGraph, ctx: pass.PassContext) void {
    std.debug.assert(!self.dirty);

    for (self.sorted.items) |n| n.execute(ctx);
}