// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const AssetId = @import("AssetId.zig");
const AssetKind = @import("AssetKind.zig").AssetKind;
const Source = @import("sources/Source.zig");

pub const CacheEntry = struct {
    asset: AssetKind,
    rc: std.atomic.Value(u32),
    time_freed: ?std.Io.Timestamp
};

const Cache = @This();
allocator: std.mem.Allocator,
io: std.Io,
entries: std.HashMap(AssetId, CacheEntry, AssetId.MapContext, std.hash_map.default_max_load_percentage),
pending_frees: std.ArrayList(AssetId),
grace_ns: i96 = 2 * std.time.ns_per_s,

pub fn init(allocator: std.mem.Allocator, io: std.Io) Cache {
    return .{ 
        .allocator = allocator,
        .io = io,
        .entries = .init(allocator),
        .pending_frees = .empty
    };
}

pub fn deinit(self: *Cache) void {
    var iter = self.entries.iterator();
    while (iter.next()) |e| {
        e.key_ptr.deinit(self.allocator);
        e.value_ptr.asset.deinit(self.allocator);
    }

    self.entries.deinit();
    self.pending_frees.deinit(self.allocator);
}

pub fn load(self: *Cache, source: Source, uri: []const u8, path: []const u8) !AssetId {
    const lookup_id: AssetId = .fromPath(uri);

    if (self.entries.getPtr(lookup_id)) |e| {
        _ = e.rc.fetchAdd(1, .monotonic);
        e.time_freed = null;
        return lookup_id;
    }

    const bytes = try source.read(path);
    const owned_name = try self.allocator.dupe(u8, uri);
    const stored_id: AssetId = .fromPath(owned_name);

    try self.entries.put(stored_id, .{
        .asset = try .parse(self.allocator, self.io, path, bytes),
        .rc = .init(1),
        .time_freed = null
    });

    return lookup_id;
}

pub fn ref(self: *Cache, id: AssetId) void {
    const entry = self.entries.getPtr(id) orelse return;
    _ = entry.rc.fetchAdd(1, .monotonic);
    entry.time_freed = null;
}

pub fn deref(self: *Cache, id: AssetId) void {
    const entry = self.entries.getPtr(id) orelse return;
    const prev = entry.rc.fetchSub(1, .acq_rel);

    if (prev == 1) {
        entry.time_freed = .now(self.io, .awake);
        self.pending_frees.append(self.allocator, id) catch {};
    }
}

pub fn getData(self: *Cache, id: AssetId) ?*AssetKind {
    const entry = self.entries.getPtr(id) orelse return null;
    return &entry.asset;
}

// Returns the number of assets purged this tick.
pub fn tick(self: *Cache) usize {
    const now: std.Io.Timestamp = .now(self.io, .awake);
    var i: usize = 0;
    var freed: usize = 0;

    while (i < self.pending_frees.items.len) {
        const id = self.pending_frees.items[i];
        const entry = self.entries.getPtr(id) orelse {
            _ = self.pending_frees.swapRemove(i);
            continue;
        };

        if (entry.rc.load(.acquire) != 0) {
            _ = self.pending_frees.swapRemove(i);
            continue;
        }

        const freed_at = entry.time_freed orelse now;
        if (freed_at.durationTo(now).toNanoseconds() < self.grace_ns) {
            i += 1;
            continue;
        }

        id.deinit(self.allocator);
        entry.asset.deinit(self.allocator);
        _ = self.entries.remove(id);
        _ = self.pending_frees.swapRemove(i);
        freed += 1;
    }

    return freed;
}