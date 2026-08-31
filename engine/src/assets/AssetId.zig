// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const builtin = @import("builtin");
const runtime_safety = builtin.mode == .Debug or builtin.mode == .ReleaseSafe;

const AssetId = @This();
name: if (runtime_safety) []const u8 else void,
value: u64,

pub fn fromPath(path: []const u8) AssetId {
    if (runtime_safety and std.mem.find(u8, path, "://") == null) {
        std.log.err("'{s}': the path provided to AssetId.fromPath() must always include the uri scheme", .{ path });
        @panic("the path provided to AssetId.fromPath() must always include the uri scheme");
    }

    return .{ 
        .value = std.hash.Fnv1a_64.hash(path),
        .name = if (runtime_safety) path else {}
    };
}

pub fn eql(self: AssetId, other: AssetId) bool {
    return self.value == other.value;
}

pub fn format(
    self: AssetId,
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    if (runtime_safety) {
        writer.print("{s} ({x:0>16})", .{ self.name, self.value });
    } else {
        writer.print("{x:0>16}", .{ self.value });
    }
}

pub const MapContext = struct {
    pub fn hash(self: MapContext, key: AssetId) u64 {
        _ = self;
        var hasher = std.hash.Wyhash.init(0);

        std.hash.autoHash(&hasher, key.value);
        return hasher.final();
    }

    pub fn eql(self: MapContext, a: AssetId, b: AssetId) bool {
        _ = self;
        return a.eql(b);
    }
};
