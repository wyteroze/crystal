// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const types = @import("types.zig");
const Cache = @import("Cache.zig");
const AssetId = @import("AssetId.zig");
const AssetKind = @import("AssetKind.zig").AssetKind;

const AssetHandle = @This();
cache: *Cache,
id: AssetId,

pub fn acquire(cache: *Cache, id: AssetId) !AssetHandle {
    return .{ .cache = cache, .id = id };
}

pub fn clone(self: AssetHandle) AssetHandle {
    self.cache.ref(self.id);
    return self;
}

pub fn release(self: AssetHandle) void {
    self.cache.deref(self.id);
}

pub fn kind(self: AssetHandle) ?*AssetKind {
    return self.cache.getData(self.id);
}

pub fn mesh(self: AssetHandle) !*const types.Mesh {
    const k = self.kind() orelse return error.AssetNotLoaded;
    return switch (k.*) {
        .mesh => |*m| m,
        else => error.WrongAssetKind
    };
}

pub fn scriptSource(self: AssetHandle) !*const types.ScriptSource {
    const k = self.kind() orelse return error.AssetNotLoaded;
    return switch (k.*) {
        .script_source => |*s| s,
        else => error.WrongAssetKind
    };
}

const std = @import("std");
pub const __lua = .val;
pub const __opaque = true;
pub fn format(self: AssetHandle, buf: []u8) []const u8 {
    return std.fmt.bufPrint(buf, "Asset {f}", .{ self.id })
        catch "Asset ?";
}